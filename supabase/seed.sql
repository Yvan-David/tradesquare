-- Demo / bootstrap data previously hard-coded in Flutter mock_data.
-- Run after schema migration. Safe to re-run (upserts by primary key).

insert into interest_options (label) values
  ('Packaging'),
  ('Logistics'),
  ('Food exports'),
  ('Renewables'),
  ('Retail growth'),
  ('Cold chain')
on conflict (label) do nothing;

insert into categories (id, name, industry, description) values
  ('agriculture', 'Agriculture', 'Agriculture', 'Farm inputs, crops, and value-chain support.'),
  ('food-processing', 'Food processing', 'Food processing', 'Processed foods, packaging and food safety.'),
  ('manufacturing', 'Manufacturing', 'Manufacturing', 'Industrial manufacturing and assembly.'),
  ('retail-wholesale', 'Retail & wholesale', 'Retail & wholesale', 'Distribution, wholesale and buyer-facing commerce.'),
  ('construction', 'Construction', 'Construction', 'Materials, systems and project support.'),
  ('logistics', 'Logistics', 'Logistics', 'Freight, warehousing and last-mile transport.'),
  ('it-services', 'IT Services', 'Information technology', 'Digital services, software and hardware support.'),
  ('textiles', 'Textiles & fashion', 'Textiles & fashion', 'Garments, raw fabrics and accessories.'),
  ('packaging', 'Packaging', 'Packaging', 'Sustainable packaging material and supplies.'),
  ('renewable-energy', 'Renewable energy', 'Renewable energy', 'Solar, storage and energy efficiency.')
on conflict (id) do update set
  name = excluded.name,
  industry = excluded.industry,
  description = excluded.description;

-- Profiles first without business_id (FK filled after businesses).
insert into profiles (
  id, full_name, email, phone, country, city, preferred_language,
  role, status, join_date, profile_completeness, photo_url
) values
  ('usr_001', 'Aline Uwimana', 'aline@agrihub.rw', '+250788420101', 'Rwanda', 'Kigali', 'en',
   'business_owner', 'active', '2024-02-13T00:00:00Z', 92,
   'https://images.unsplash.com/photo-1494790108377-be9c29b29330'),
  ('usr_002', 'Duncan Muriithi', 'duncan@freshsource.ke', '+254712660221', 'Kenya', 'Nairobi', 'en',
   'buyer', 'active', '2024-05-21T00:00:00Z', 88,
   'https://images.unsplash.com/photo-1500648767791-00dcc994a43e'),
  ('usr_003', 'Miriam Kamanzi', 'miriam@elevatepack.ug', '+256772901432', 'Uganda', 'Kampala', 'en',
   'supplier', 'active', '2023-11-04T00:00:00Z', 96,
   'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f'),
  ('usr_004', 'Joseph Msuya', 'joseph@greenline.tz', '+255712334455', 'Tanzania', 'Dar es Salaam', 'sw',
   'business_owner', 'pending', '2025-01-15T00:00:00Z', 74,
   'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d'),
  ('usr_005', 'TradeSquare Admin', 'admin@tradesquare.africa', '+250788000111', 'Rwanda', 'Kigali', 'fr',
   'administrator', 'active', '2023-01-10T00:00:00Z', 100,
   'https://images.unsplash.com/photo-1504593811423-6dd665756598'),
  ('usr_006', 'Claire Nabwire', 'claire@lakeregionlogistics.ug', '+256701882201', 'Uganda', 'Kampala', 'en',
   'supplier', 'active', '2024-06-01T00:00:00Z', 88, null),
  ('usr_007', 'Eric Ndayishimiye', 'eric@bujumburawholesale.bi', '+257799001123', 'Burundi', 'Bujumbura', 'fr',
   'buyer', 'active', '2024-09-01T00:00:00Z', 79, null),
  ('usr_008', 'Grace Wanjiku', 'grace@nairobitfab.ke', '+254711334401', 'Kenya', 'Nairobi', 'en',
   'supplier', 'active', '2024-03-01T00:00:00Z', 94, null),
  ('usr_009', 'Hassan Juma', 'hassan@horizonfoods.tz', '+255754221101', 'Tanzania', 'Arusha', 'sw',
   'business_owner', 'active', '2024-07-01T00:00:00Z', 90, null),
  ('usr_010', 'Diane Mukamana', 'diane@buildright.rw', '+250788667701', 'Rwanda', 'Kigali', 'en',
   'buyer', 'active', '2024-08-01T00:00:00Z', 85, null)
on conflict (id) do update set
  full_name = excluded.full_name,
  email = excluded.email,
  phone = excluded.phone,
  country = excluded.country,
  city = excluded.city,
  preferred_language = excluded.preferred_language,
  role = excluded.role,
  status = excluded.status,
  profile_completeness = excluded.profile_completeness,
  photo_url = excluded.photo_url;

insert into businesses (
  id, name, logo_url, description, industry, category, country, province, city, address,
  email, phone, website, registration_number, registration_certificate_type,
  certificate_submission_status, verification_status, business_size, year_established,
  products_offered, products_needed, business_interests, preferred_markets,
  owner_id, profile_completeness, created_at
) values
  ('biz_000', 'TradeSquare Platform', null,
   'Internal TradeSquare operator account.',
   'Platform', 'Operations', 'Rwanda', 'Kigali', 'Kigali', 'Kigali',
   'admin@tradesquare.africa', '+250788000111', 'https://tradesquare.africa',
   'RW-PLT-000', 'Certificate of Incorporation', 'Approved', 'approved',
   '1-10 staff', 2023, '{}', '{}', '{}', '{}', 'usr_005', 100, '2023-01-10T00:00:00Z'),
  ('biz_001', 'AgriHub Rwanda',
   'https://images.unsplash.com/photo-1501004318641-b39e6451bec6',
   'Rwandan grower and processor of rice, beans and horticultural produce.',
   'Agriculture', 'Food production', 'Rwanda', 'Kigali', 'Kigali', 'KN 5 Avenue, Kigali',
   'hello@agrihub.rw', '+250788402501', 'https://agrihub.rw',
   'RW-BIZ-2024-001', 'Certificate of Incorporation', 'Approved', 'approved',
   '51-200 staff', 2018,
   array['Rice','Beans','Fresh vegetables'],
   array['Packaging materials','Cold storage equipment'],
   array['Packaging','Logistics','Agri-finance'],
   array['Kenya','Uganda','DR Congo'],
   'usr_001', 93, '2024-01-22T00:00:00Z'),
  ('biz_002', 'FreshSource Kenya',
   'https://images.unsplash.com/photo-1581092921461-eab62e97a780',
   'Fresh produce importer and distributor serving urban retailers.',
   'Retail & wholesale', 'Fresh food distribution', 'Kenya', 'Nairobi County', 'Nairobi', 'Mombasa Road, Nairobi',
   'sales@freshsource.ke', '+254700123900', 'https://freshsource.ke',
   'KE-BIZ-2023-190', 'Certificate of Registration', 'Under review', 'under_review',
   '11-50 staff', 2016,
   array['Avocados','Fresh fruits','Vegetable packs'],
   array['Packaging','Temperature-controlled transport'],
   array['Import-export','Cold chain','Retail growth'],
   array['Rwanda','Uganda','Tanzania'],
   'usr_002', 87, '2024-02-10T00:00:00Z'),
  ('biz_003', 'ElevatePack Uganda',
   'https://images.unsplash.com/photo-1553413077-190dd305871c',
   'Sustainable packaging and carton manufacturing for food and consumer goods.',
   'Packaging', 'Packaging materials', 'Uganda', 'Central', 'Kampala', 'Plot 7 Ntinda Road, Kampala',
   'info@elevatepack.ug', '+256772901111', 'https://elevatepack.ug',
   'UG-BIZ-2019-447', 'Business Registration Certificate', 'Submitted', 'submitted',
   '51-200 staff', 2015,
   array['Cartons','Flexible packaging','Pallet wraps'],
   array['Agri-supply partnerships','Packaging design input'],
   array['Food packaging','Sustainable materials','Distribution'],
   array['Rwanda','Kenya','Tanzania'],
   'usr_003', 96, '2023-08-14T00:00:00Z'),
  ('biz_004', 'GreenLine Tanzania',
   'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a',
   'Solar equipment and renewable energy solutions for SMEs and industrial sites.',
   'Renewable energy', 'Energy systems', 'Tanzania', 'Dar es Salaam', 'Dar es Salaam', 'Sam Nujoma Road, Dar es Salaam',
   'hello@greenline.tz', '+255712334455', 'https://greenline.tz',
   'TZ-BIZ-2025-018', 'Certificate of Incorporation', 'Additional information required',
   'additional_information_required',
   '11-50 staff', 2020,
   array['Solar panels','Inverters','Maintenance packages'],
   array['Distribution partners','Agricultural cooling demand'],
   array['Renewables','Manufacturing','Clean energy'],
   array['Kenya','Uganda','Rwanda'],
   'usr_004', 74, '2025-01-15T00:00:00Z'),
  ('biz_005', 'Kigali Textiles Co-op',
   'https://images.unsplash.com/photo-1558171813-4c088753af8f',
   'Apparel and textile manufacturer producing school uniforms and workwear for East African buyers.',
   'Textiles', 'Apparel manufacturing', 'Rwanda', 'Kigali', 'Kigali', 'Special Economic Zone, Kigali',
   'orders@kigalitextiles.rw', '+250788555210', 'https://kigalitextiles.rw',
   'RW-BIZ-2021-088', 'Certificate of Incorporation', 'Approved', 'approved',
   '51-200 staff', 2014,
   array['School uniforms','Workwear','Cotton fabric'],
   array['Zippers','Industrial sewing machines'],
   array['Export','Education supply','Manufacturing'],
   array['Uganda','Kenya','Burundi'],
   'usr_005', 91, '2024-05-03T00:00:00Z'),
  ('biz_006', 'Lake Region Logistics',
   'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d',
   'Cross-border freight and warehousing for agro-food and packaging shipments.',
   'Logistics', 'Freight & warehousing', 'Uganda', 'Central', 'Kampala', 'Jinja Road Industrial Area, Kampala',
   'ops@lakeregionlogistics.ug', '+256701882200', 'https://lakeregionlogistics.ug',
   'UG-BIZ-2018-302', 'Business Registration Certificate', 'Approved', 'approved',
   '11-50 staff', 2017,
   array['Cross-border freight','Cold storage slots','Last-mile delivery'],
   array['Fleet partners','Packaging volume'],
   array['Cold chain','Agri trade','Regional distribution'],
   array['Rwanda','Kenya','Tanzania'],
   'usr_006', 88, '2024-06-18T00:00:00Z'),
  ('biz_007', 'Bujumbura Wholesale Hub',
   'https://images.unsplash.com/photo-1441986300917-64674bd600d8',
   'Wholesale distributor of staples, building materials and household goods across Burundi.',
   'Wholesale', 'General wholesale', 'Burundi', 'Bujumbura Mairie', 'Bujumbura', 'Boulevard de la Liberté, Bujumbura',
   'trade@bujumburawholesale.bi', '+257799001122', 'https://bujumburawholesale.bi',
   'BI-BIZ-2022-044', 'Certificate of Registration', 'Under review', 'under_review',
   '11-50 staff', 2019,
   array['Rice wholesale','Cement bags','Household goods'],
   array['Reliable exporters','Packaging suppliers'],
   array['Import','Construction supply','Food staples'],
   array['Rwanda','Tanzania','DR Congo'],
   'usr_007', 79, '2024-09-12T00:00:00Z'),
  ('biz_008', 'Nairobi Tech Fabricators',
   'https://images.unsplash.com/photo-1581092160562-40aa08e78837',
   'Metal fabrication and school furniture manufacturing for education and commercial buyers.',
   'Manufacturing', 'Furniture & metalwork', 'Kenya', 'Nairobi County', 'Nairobi', 'Industrial Area, Nairobi',
   'sales@nairobitfab.ke', '+254711334400', 'https://nairobitfab.ke',
   'KE-BIZ-2017-551', 'Certificate of Incorporation', 'Approved', 'approved',
   '51-200 staff', 2012,
   array['School desks','Office furniture','Metal frames'],
   array['Timber partners','Distribution in Uganda'],
   array['Education supply','Export','Manufacturing'],
   array['Uganda','Rwanda','Tanzania'],
   'usr_008', 94, '2024-03-28T00:00:00Z'),
  ('biz_009', 'Horizon Food Processing',
   'https://images.unsplash.com/photo-1504674900247-0877df9cc836',
   'Food processing plant producing maize flour, cooking oil and packaged staples.',
   'Food processing', 'Agro-processing', 'Tanzania', 'Arusha', 'Arusha', 'Njiro Industrial Area, Arusha',
   'hello@horizonfoods.tz', '+255754221100', 'https://horizonfoods.tz',
   'TZ-BIZ-2020-220', 'Certificate of Incorporation', 'Approved', 'approved',
   '51-200 staff', 2016,
   array['Maize flour','Cooking oil','Packaged staples'],
   array['Raw maize','Flexible packaging'],
   array['Agri trade','Packaging','Retail growth'],
   array['Kenya','Rwanda','Burundi'],
   'usr_009', 90, '2024-07-09T00:00:00Z'),
  ('biz_010', 'BuildRight Construction Supply',
   'https://images.unsplash.com/photo-1503387762-592deb58ef4e',
   'Construction materials distributor serving contractors across Rwanda and nearby markets.',
   'Construction', 'Building materials', 'Rwanda', 'Kigali', 'Kigali', 'Gikondo Industrial Park, Kigali',
   'sales@buildright.rw', '+250788667700', 'https://buildright.rw',
   'RW-BIZ-2019-312', 'Certificate of Incorporation', 'Submitted', 'submitted',
   '11-50 staff', 2018,
   array['Cement','Steel bars','Roofing sheets'],
   array['Regional suppliers','Logistics partners'],
   array['Construction','Import','Wholesale'],
   array['Burundi','Uganda','DR Congo'],
   'usr_010', 85, '2024-08-21T00:00:00Z')
on conflict (id) do update set
  name = excluded.name,
  logo_url = excluded.logo_url,
  description = excluded.description,
  industry = excluded.industry,
  category = excluded.category,
  verification_status = excluded.verification_status,
  products_offered = excluded.products_offered,
  products_needed = excluded.products_needed,
  business_interests = excluded.business_interests,
  preferred_markets = excluded.preferred_markets,
  owner_id = excluded.owner_id,
  profile_completeness = excluded.profile_completeness;

update profiles set business_id = 'biz_001' where id = 'usr_001';
update profiles set business_id = 'biz_002' where id = 'usr_002';
update profiles set business_id = 'biz_003' where id = 'usr_003';
update profiles set business_id = 'biz_004' where id = 'usr_004';
update profiles set business_id = 'biz_000' where id = 'usr_005';
update profiles set business_id = 'biz_006' where id = 'usr_006';
update profiles set business_id = 'biz_007' where id = 'usr_007';
update profiles set business_id = 'biz_008' where id = 'usr_008';
update profiles set business_id = 'biz_009' where id = 'usr_009';
update profiles set business_id = 'biz_010' where id = 'usr_010';

insert into product_listings (
  id, business_id, name, product_image, description, category, industry, condition, unit,
  available_quantity, minimum_order_quantity, indicative_price, currency, country_of_origin,
  delivery_locations, availability_status, listing_status, published_at, views, saved_count
) values
  ('prod_001', 'biz_001', 'Premium rice',
   'https://images.unsplash.com/photo-1586201375761-83865001e0e2',
   'High-quality aromatic rice grown in Rwanda for institutional and retail buyers.',
   'Food production', 'Agriculture', 'New', 'kg', 2200, 250, 980, 'RWF', 'Rwanda',
   array['Kigali','Nairobi','Kampala'], 'In stock', 'Active', '2026-10-20T00:00:00Z', 1480, 126),
  ('prod_002', 'biz_003', 'Sustainable food carton packs',
   'https://images.unsplash.com/photo-1556740749-887f6717d7e4',
   'Recyclable cartons for grains, spices and food products.',
   'Packaging materials', 'Packaging', 'New', 'carton', 1600, 200, 3600, 'UGX', 'Uganda',
   array['Kampala','Kigali','Dar es Salaam'], 'In stock', 'Active', '2026-11-02T00:00:00Z', 920, 84),
  ('prod_003', 'biz_004', 'Solar micro-grid kit',
   'https://images.unsplash.com/photo-1497440001374-f26997328c1b',
   'Solar power package for schools, clinics and SME workshops.',
   'Energy systems', 'Renewable energy', 'New', 'unit', 45, 3, 4200, 'USD', 'Tanzania',
   array['Dar es Salaam','Nairobi','Kigali'], 'Limited stock', 'Active', '2026-10-29T00:00:00Z', 660, 51),
  ('prod_004', 'biz_002', 'Fresh avocado boxes',
   'https://images.unsplash.com/photo-1601493700631-2b16ec4b4716',
   'Export-ready avocado boxes with quality sorting and packaging.',
   'Fresh food distribution', 'Retail & wholesale', 'Fresh', 'box', 500, 50, 3200, 'KES', 'Kenya',
   array['Nairobi','Kigali','Kampala'], 'In stock', 'Active', '2026-11-04T00:00:00Z', 1180, 104)
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  available_quantity = excluded.available_quantity,
  indicative_price = excluded.indicative_price,
  views = excluded.views,
  saved_count = excluded.saved_count;

insert into buying_requests (
  id, buyer_business_id, product_or_service, description, category, required_quantity, unit,
  target_price_range, currency, delivery_destination, preferred_supplier_location,
  deadline, urgency, status, published_at
) values
  ('req_001', 'biz_002', 'Avocados',
   'Need consistent shipments of premium avocados for supermarket distribution in Nairobi.',
   'Fresh food distribution', 1200, 'kg', 'KES 180 - 230 / kg', 'KES', 'Nairobi', 'Kenya',
   '2026-12-10T00:00:00Z', 'High', 'Open', '2026-11-05T00:00:00Z'),
  ('req_002', 'biz_001', 'Packaging materials',
   'Looking for durable packaging solutions for rice and dry goods exports.',
   'Food production', 600, 'carton', 'RWF 2200 - 3300 / carton', 'RWF', 'Kigali', 'Uganda',
   '2026-12-15T00:00:00Z', 'Medium', 'Open', '2026-11-01T00:00:00Z'),
  ('req_003', 'biz_004', 'Solar energy systems',
   'Need modular solar kits for clinics and retail sites in northern Tanzania.',
   'Energy systems', 12, 'unit', 'USD 4,200 - 6,800 / unit', 'USD', 'Arusha', 'Rwanda',
   '2026-12-20T00:00:00Z', 'High', 'Open', '2026-11-07T00:00:00Z')
on conflict (id) do update set
  description = excluded.description,
  status = excluded.status,
  urgency = excluded.urgency;

insert into business_connections (
  id, requesting_business_id, receiving_business_id, status, request_date,
  relationship_type, introductory_message
) values
  ('conn_001', 'biz_001', 'biz_003', 'accepted', '2026-10-18T00:00:00Z', 'supplier',
   'We are interested in expanding our packaging partnership for rice exports.'),
  ('conn_002', 'biz_002', 'biz_001', 'pending', '2026-11-03T00:00:00Z', 'buyer',
   'We would like to discuss recurring produce demand and shared delivery schedules.'),
  ('conn_003', 'biz_004', 'biz_003', 'blocked', '2026-10-22T00:00:00Z', 'supplier',
   'We are exploring packaging for energy product transport.')
on conflict (id) do update set
  status = excluded.status,
  introductory_message = excluded.introductory_message;

insert into business_verifications (business_id, status, review_message, last_updated) values
  ('biz_001', 'approved', 'Approved for active marketplace trading.', '2026-10-21T00:00:00Z'),
  ('biz_004', 'additional_information_required',
   'Please upload a clearer certificate and confirm directors.', '2026-11-02T00:00:00Z')
on conflict (business_id) do update set
  status = excluded.status,
  review_message = excluded.review_message,
  last_updated = excluded.last_updated;

insert into conversations (id, business_relationship) values
  ('conv_001', 'supplier'),
  ('conv_002', 'buyer'),
  ('conv_003', 'buyer'),
  ('conv_004', 'supplier')
on conflict (id) do update set business_relationship = excluded.business_relationship;

insert into conversation_participants (conversation_id, profile_id) values
  ('conv_001', 'usr_001'), ('conv_001', 'usr_003'),
  ('conv_002', 'usr_002'), ('conv_002', 'usr_001'),
  ('conv_003', 'usr_001'), ('conv_003', 'usr_004'),
  ('conv_004', 'usr_001'), ('conv_004', 'usr_005')
on conflict do nothing;

insert into messages (
  id, conversation_id, sender_id, body, message_type, read_status,
  attachment_name, voice_duration, created_at
) values
  ('msg_001', 'conv_001', 'usr_001',
   'Can we confirm the rice carton packaging for the next shipment?',
   'text', 'read', null, null, '2026-11-05T08:15:00Z'),
  ('msg_002', 'conv_001', 'usr_003',
   'Yes. We can deliver 600 cartons by 15 December with labels included.',
   'text', 'read', null, null, '2026-11-05T08:18:00Z'),
  ('msg_002b', 'conv_001', 'usr_003', 'Updated packaging quote',
   'attachment', 'read', 'ElevatePack_Quote_Dec.pdf', null, '2026-11-05T08:19:00Z'),
  ('msg_003', 'conv_001', 'usr_001',
   'Great. Please share the final quote and delivery window.',
   'text', 'read', null, null, '2026-11-12T14:20:00Z'),
  ('msg_003b', 'conv_001', 'usr_003',
   'Delivery window confirmed for 12–15 December from Kampala.',
   'text', 'unread', null, null, '2026-11-12T14:42:00Z'),
  ('msg_004', 'conv_002', 'usr_002',
   'We want to discuss recurring avocado supply for the next quarter.',
   'text', 'read', null, null, '2026-11-04T11:00:00Z'),
  ('msg_005', 'conv_002', 'usr_001',
   'We can provide a stable volume and cold-chain coordination from Kigali.',
   'text', 'read', null, null, '2026-11-04T11:06:00Z'),
  ('msg_005b', 'conv_002', 'usr_002',
   'Perfect — can we hop on a short call this week?',
   'text', 'unread', null, null, '2026-11-11T09:14:00Z'),
  ('msg_005c', 'conv_002', 'usr_002', 'Voice note',
   'voice', 'unread', null, '0:28', '2026-11-11T09:15:00Z'),
  ('msg_006', 'conv_003', 'usr_004',
   'Habari. Tunahitaji ugavi wa maharagwe kwa soko la Dar es Salaam.',
   'text', 'read', null, null, '2026-11-10T16:05:00Z'),
  ('msg_007', 'conv_003', 'usr_001',
   'Hello Joseph — we can supply graded beans with weekly dispatch to Dar.',
   'text', 'read', null, null, '2026-11-10T16:22:00Z'),
  ('msg_008', 'conv_003', 'usr_004',
   'Asante. Tuongee kwa simu kesho ili tukubaliane bei.',
   'text', 'unread', null, null, '2026-11-12T07:40:00Z'),
  ('msg_009', 'conv_004', 'usr_005',
   'Your business verification documents look complete. Let us know if you need export support.',
   'text', 'read', null, null, '2026-11-08T13:00:00Z'),
  ('msg_010', 'conv_004', 'usr_001',
   'Thank you — we may need help preparing buyer introductions.',
   'text', 'read', null, null, '2026-11-08T13:18:00Z'),
  ('msg_011', 'conv_004', 'usr_005', 'Warehouse reference photo',
   'image', 'read', 'kigali_warehouse.jpg', null, '2026-11-09T10:02:00Z')
on conflict (id) do update set
  body = excluded.body,
  read_status = excluded.read_status;

insert into notifications (
  id, type, title, description, created_at, is_read, recipient_id, destination
) values
  ('not_001', 'new_connection', 'New connection request',
   'FreshSource Kenya wants to connect on a quarterly rice distribution partnership.',
   '2026-11-05T08:45:00Z', false, 'usr_001', '/connections'),
  ('not_002', 'new_message', 'New message',
   'Miriam from ElevatePack sent details on carton packaging for December.',
   '2026-11-05T09:10:00Z', false, 'usr_001', '/messages/conv_001'),
  ('not_003', 'ai_recommendation', 'TradeSquare AI recommendation',
   'Packaging suppliers in Uganda match your recent product interest and delivery requirements.',
   '2026-11-04T15:30:00Z', true, 'usr_001', '/ai')
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  is_read = excluded.is_read;

insert into feed_items (
  id, type, source_business_id, title, summary, created_at, relevance_explanation, action_metadata
) values
  ('feed_001', 'product', 'biz_003', 'Sustainable packaging for food brands',
   'ElevatePack Uganda offers carton and flexible packaging for food exporters.',
   '2026-11-05T08:30:00Z',
   'Matches the packaging interest in your business profile.',
   '{"action":"view_listing","listingId":"prod_002"}'::jsonb),
  ('feed_002', 'buyer_request', 'biz_002', 'Fresh avocado demand',
   'Kenyan buyer is seeking regular avocado shipments for the next quarter.',
   '2026-11-03T13:15:00Z',
   'Relevant because your business operates in related horticulture demand.',
   '{"action":"respond_request","requestId":"req_001"}'::jsonb),
  ('feed_003', 'business', 'biz_001', 'AgriHub Rwanda',
   'Regional rice and bean supplier exploring logistics and packaging partners.',
   '2026-11-02T17:00:00Z',
   'Good strategic fit for market expansion and regional trade.',
   '{"action":"view_profile","businessId":"biz_001"}'::jsonb)
on conflict (id) do update set
  title = excluded.title,
  summary = excluded.summary,
  action_metadata = excluded.action_metadata;

insert into analytics_summaries (business_id, metric, value, delta, period, unit) values
  ('biz_001', 'Product views', 18420, 12.8, '30d', 'views'),
  ('biz_001', 'Connection requests', 86, 6.4, '30d', 'requests'),
  ('biz_001', 'Conversion interest', 17, 3.2, '30d', '%');
