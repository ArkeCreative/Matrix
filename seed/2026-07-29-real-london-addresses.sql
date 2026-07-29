-- =============================================================================
-- Real central-London addresses for the 30 fictional projects
-- Applied to tpxabhqsjngalilbznhz on 2026-07-29.
-- =============================================================================
-- The seeded addresses were invented, so a postcode could be read off the tail
-- and then fail to resolve — or worse, resolve to somewhere the street name
-- does not match. That is a misleading failure: the map would place a pin
-- confidently in the wrong place.
--
-- These are real, well-known central-London buildings, chosen because their
-- street-to-postcode pairing is widely documented and stable. All 30 postcodes
-- are distinct, so no two pins stack.
--
-- NOTE ON NAMES: address correctness was prioritised over name/place agreement,
-- since the map reads the address, not the name. Two projects now sit away from
-- the place in their name — "Croydon Gateway" (Kingsway, WC2B) and
-- "Wembley Point" (Leadenhall Street, EC3V) — because the brief was to keep
-- everything in central London. Rename those two projects if the mismatch grates.

update projects p set address = v.addr
from (values
  ('Aldgate Point',         'Aldgate Tower, 2 Leman Street, London E1 8FA'),
  ('Ashworth Legal',        '53-64 Chancery Lane, London WC2A 1QS'),
  ('Barbican Print Works',  '1 Silk Street, London EC2Y 8DS'),
  ('Bermondsey Yard',       '52 Tanner Street, London SE1 3PH'),
  ('Brightside Media',      'The Tea Building, 56 Shoreditch High Street, London E1 6JJ'),
  ('Brompton Wharf',        '55 Broadway, London SW1H 0BD'),
  ('Camberwell Exchange',   'Millbank, London SW1P 4RG'),
  ('Croydon Gateway',       '2 Kingsway, London WC2B 6NH'),
  ('Elephant Works',        '32 London Bridge Street, London SE1 9SG'),
  ('Farringdon Vaults',     '1 Turnmill Street, London EC1M 5QA'),
  ('Fitzrovia Yard',        '60 Holborn Viaduct, London EC1A 2FD'),
  ('Halcyon Group Limited', '1 Bishops Square, London E1 6AD'),
  ('Kestrel & Co.',         'Somerset House, Strand, London WC2R 1LA'),
  ('Kingfisher House',      '100 Liverpool Street, London EC2M 2AT'),
  ('Lumen Health',          '1 Finsbury Avenue, London EC2M 2PF'),
  ('Marlow Studios',        '90 York Way, London N1 9AG'),
  ('Meridian Capital',      '30 St Mary Axe, London EC3A 8BF'),
  ('Northwind Partners',    '20 Farringdon Road, London EC1M 3HE'),
  ('Orbit Digital',         '7 Curtain Road, London EC2A 3LT'),
  ('Paddington Exchange',   '1 Granary Square, London N1C 4AB'),
  ('Regent Quarter',        'Stable Street, London N1C 4DQ'),
  ('Renowned HQ',           '1 Old Street Yard, London EC1Y 8AF'),
  ('Sable & Finch',         '1 Poultry, London EC2R 8EJ'),
  ('Shoreditch Loft',       '14 Hoxton Square, London N1 6NT'),
  ('Southbank Print House', '30 Stamford Street, London SE1 9LQ'),
  ('Tattersall House',      '14-18 Finsbury Square, London EC2A 1AH'),
  ('Vantage Aerospace HQ',  '20 Fenchurch Street, London EC3M 8AF'),
  ('Voltaic Labs',          '3 Queen Victoria Street, London EC4N 4TQ'),
  ('Wembley Point',         '122 Leadenhall Street, London EC3V 4AB'),
  ('Westlake Court',        'Bankside, London SE1 9TG')
) as v(nm, addr)
where p.name = v.nm;

-- Verified after applying: 30 rows updated, 30 extract a postcode with the
-- app's regex, 30 DISTINCT postcodes (no pin stacking).
--
-- ⚠ NOT verifiable from the dev sandbox: whether each postcode RESOLVES via
-- api.postcodes.io — outbound calls to it are blocked here. The map's own
-- status line ("N of 30 addresses located") is the check. Any that fail land in
-- the notice under the map, which distinguishes "no postcode in the address"
-- from "postcode read but not recognised".
