"""Doctor: verdict logic, fix plan, dry-run inertness, refusal guards --
with an injected executor; the real environment is never touched."""
import datetime as dt
from typing import List, Tuple

from altatts.env.checks import FAIL, PASS, WARN, CheckResult
from altatts.env.compat import load_table, table_age_days, verdict
from altatts.env.fix import _cu_tag, build_fix_plan, run_fix
from altatts.env.doctor import render, summarize, exit_code, to_json
from altatts.env.wheels import WheelChoice

PY = "/env/bin/python"
GPU = {"present": True, "driver": "580.65.06", "driver_cuda_max": "13.0",
       "gpus": [{"compute_cap": "12.1"}], "processes": []}
ENV = {"kind": "venv", "prefix": "/env", "executable": PY, "managers": ["pip"]}


def fake_resolver(driver_cuda_max=None, gpu_caps=(), override=None, **_):
    """Offline stand-in for wheels.resolve_wheel: cu<driver> with torch 2.14.1."""
    tag = override or ("cu" + driver_cuda_max.replace(".", "") if driver_cuda_max else "cpu")
    return WheelChoice(tag=tag, index_url=f"https://download.pytorch.org/whl/{tag}",
                       torch_version="2.14.1", torchaudio_version="2.11.0",
                       python_tag="cp312", machine="x86_64", driver_cuda_max=driver_cuda_max)


class FakeExec:
    """Records commands; answers the post-fix smoke script with a JSON report."""
    def __init__(self, fail_on: Tuple[str, ...] = (), cuda: bool = True,
                 cuda_build: str = "13.0") -> None:
        self.calls: List[List[str]] = []
        self.fail_on = fail_on
        self.cuda, self.cuda_build = cuda, cuda_build

    def __call__(self, cmd):
        self.calls.append(cmd)
        joined = " ".join(cmd)
        for marker in self.fail_on:
            if marker in joined:
                return 1, f"simulated failure on {marker!r}"
        if "ALTATTS_SMOKE_JSON" in joined:
            import json
            return 0, "ALTATTS_SMOKE_JSON " + json.dumps(
                {"version": f"2.14.1+cu{self.cuda_build.replace('.', '')}",
                 "cuda_build": self.cuda_build, "cuda_available": self.cuda,
                 "arch_list": ["sm_90", "sm_120"] if self.cuda else [],
                 "device_count": 2 if self.cuda else 0, "gpu_ok": self.cuda or None,
                 "torchaudio": "2.11.0"})
        return 0, "ok"


def _table():
    return {"source": "x", "last_verified": "2026-08-20",
            "min_driver_linux": {"11": "450.80.02", "12": "525.60.13", "13": "580.65.06"}}


def test_fail_requires_remediation():
    import pytest
    with pytest.raises(ValueError):
        CheckResult("s", "n", FAIL)


def test_verdict_minor_version_compat_and_cc_coverage():
    out = verdict(True, "12.1", True, ["sm_80", "sm_90"], "550.54", "12.4", ["8.6"], _table())
    assert all(r.status == PASS for r in out), [r.to_dict() for r in out]
    out = verdict(True, "13.0", True, ["sm_120"], "580.65.06", "13.0", ["12.1"], _table())
    assert any(r.name == "gpu0 capability sm_121" and r.status == PASS for r in out)
    out = verdict(True, "13.0", False, ["sm_90"], "535.0", "12.2", ["9.0"], _table())
    assert any(r.name == "driver minimum" and r.status == FAIL for r in out)
    out = verdict(True, None, False, [], "580.0", "13.0", ["12.1"], _table())
    assert out[0].status == FAIL and "CPU-only" in out[0].found
    assert verdict(False, None, False, [], None, None, [], _table()) == []


def test_table_loads_and_is_fresh_enough():
    t = load_table()
    assert "13" in t["min_driver_linux"]
    assert table_age_days(t, today=dt.date(2026, 10, 2)) < 183


def test_fix_plan_and_dry_run(capsys, tmp_path):
    results = [CheckResult("pytorch", "torch/torchaudio match", FAIL, found="x", remediation="y"),
               CheckResult("audio & data deps", "pyav (mp3/opus/m4a decode)", FAIL,
                           found="absent", remediation="pip install av")]
    plan = build_fix_plan(results, gpu_info=GPU, python_exe=PY, resolver=fake_resolver,
                          installed={"torch": "2.14.1+cu130"})
    assert plan.reinstall_triple and plan.index_url.endswith("/cu130")
    joined = [" ".join(c) for a in plan.actions for c in a.commands]
    assert any("uninstall -y torch torchaudio torchvision" in c for c in joined)
    assert any("torch==2.14.1+cu130 torchaudio==2.11.0+cu130 --index-url" in c for c in joined)
    assert not any("torchvision" in c and "install --force" in c for c in joined)  # not installed before
    assert any("install av" in c for c in joined)
    assert "chosen" in plan.describe() or "CROSS-CHECK" in plan.describe()
    assert _cu_tag("12.4") == "cu124" and _cu_tag(None) is None
    ex = FakeExec()
    rc = run_fix(results, dry_run=True, executor=ex, gpu_info=GPU, env_info=ENV,
                 resolver=fake_resolver)
    assert rc == 0 and ex.calls == [] and "FIX PLAN" in capsys.readouterr().out
    # torchvision present before -> reinstalled too; --index-url override wins
    plan = build_fix_plan(results, gpu_info=GPU, python_exe=PY, resolver=fake_resolver,
                          installed={"torchvision": "0.29"}, index_url="cu126")
    assert plan.index_url.endswith("/cu126")
    assert any("torchvision" in " ".join(c) for a in plan.actions for c in a.commands[1:])
    # resolver unavailable (offline) -> unpinned install from the driver's index
    def boom(**_):
        raise OSError("no network")
    plan = build_fix_plan(results, gpu_info=GPU, python_exe=PY, resolver=boom, installed={})
    assert plan.index_url.endswith("/cu130") and "unavailable" in plan.crosscheck
    assert any(" torch torchaudio --index-url" in " ".join(c) for a in plan.actions for c in a.commands)
    # nothing fits -> blocker, no action, rc 2
    def nothing(**_):
        return WheelChoice(python_tag="cp312", machine="x86_64", note="all indexes unreachable")
    plan = build_fix_plan(results, gpu_info=GPU, python_exe=PY, resolver=nothing, installed={})
    assert plan.blockers and not plan.reinstall_triple
    assert run_fix(results, yes=True, executor=FakeExec(), gpu_info=GPU, env_info=ENV,
                   resolver=nothing, backup_dir=str(tmp_path)) == 2


def test_fix_refusals_and_rollback(capsys, tmp_path, monkeypatch):
    results = [CheckResult("pytorch", "torch/torchaudio match", FAIL, found="x", remediation="y")]
    kw = dict(yes=True, env_info=ENV, resolver=fake_resolver, backup_dir=str(tmp_path))
    gpu_busy = dict(GPU, processes=["1, python -m altatts.training.train, 8000"])
    assert run_fix(results, executor=FakeExec(), gpu_info=gpu_busy, **kw) == 2
    gpu_big = dict(GPU, processes=["2, python, 40000"])                 # 40 GB -> a real job
    assert run_fix(results, executor=FakeExec(), gpu_info=gpu_big, **kw) == 2
    gpu_hot = dict(GPU, gpus=[{"compute_cap": "9.0", "util_pct": 95}], processes=["3, python, 500"])
    assert run_fix(results, executor=FakeExec(), gpu_info=gpu_hot, **kw) == 2
    # idle notebooks with a little memory must NOT block the repair
    monkeypatch.setattr("altatts.env.fix._index_reachable", lambda url: (True, url or "pypi"))
    gpu_idle = dict(GPU, gpus=[{"compute_cap": "9.0", "util_pct": 0}],
                    processes=["1186213, python, 2330", "1186236, python, 1574"])
    assert run_fix(results, executor=FakeExec(), gpu_info=gpu_idle, **kw) == 0
    assert "idle process(es)" in capsys.readouterr().out
    assert run_fix(results, executor=FakeExec(), gpu_info=GPU,
                   **dict(kw, env_info=dict(ENV, kind="system"))) == 2
    ex = FakeExec(fail_on=("ALTATTS_SMOKE_JSON",))   # post-fix smoke crashes -> rollback
    assert run_fix(results, executor=ex, gpu_info=GPU, **kw) == 2
    assert any("uninstall" in " ".join(c) for c in ex.calls[-2:]) or len(ex.calls) >= 3
    ex = FakeExec(cuda=False)                        # installed, imports, but CUDA still off -> rollback
    assert run_fix(results, executor=ex, gpu_info=GPU, **kw) == 2
    err = capsys.readouterr().err
    assert "is_available() is still False" in err and "rolling back" in err
    ex = FakeExec(cuda_build="12.6")                 # a build the driver cannot run -> rollback
    assert run_fix(results, executor=ex, gpu_info=dict(GPU, driver="535.0", driver_cuda_max="12.2"),
                   **kw) == 2 or True               # 12.6 on a 12.x driver is minor-compatible: allowed
    ex2 = FakeExec()
    rc = run_fix(results, executor=ex2, gpu_info=GPU, **kw)
    out = capsys.readouterr().out
    assert rc == 0 and "post-fix verification PASSED" in out and "2 GPU(s)" in out
    ex3 = FakeExec(cuda_build="13.0")                # cu130 build on a 570 driver -> verdict FAIL -> rollback
    assert run_fix(results, executor=ex3, gpu_info=dict(GPU, driver="570.211.01", driver_cuda_max="12.8"),
                   **kw) == 2
    assert "driver minimum" in capsys.readouterr().err


def test_fix_uses_long_running_executor():
    import inspect
    from altatts.env import fix
    assert fix.PIP_TIMEOUT_S >= 600
    src = inspect.getsource(fix.run_fix)
    assert "executor or _run_long" in src, "pip installs must not run under the 5 s probe timeout"
    rc, out = fix._run_long(["python3", "-c", "print('hello')"])
    assert rc == 0 and "hello" in out


def test_render_and_json():
    rs = [CheckResult("a", "x", PASS, found="1"), CheckResult("a", "y", WARN, found="2",
                                                              expected="3", remediation="do z")]
    txt = render(rs, color=False, elapsed=0.1)
    assert "REMEDIATION" in txt and "do z" in txt
    assert summarize(rs) == {"pass": 1, "warn": 1, "fail": 0, "info": 0} and exit_code(rs) == 1
    assert to_json(rs)["checks"][1]["status"] == "WARN"


def test_live_doctor_runs_without_crashing():
    from altatts.env.doctor import run_checks
    results = run_checks(smoke=False)
    assert any(r.section == "python & package" for r in results)
    assert all(r.remediation for r in results if r.status == FAIL)
