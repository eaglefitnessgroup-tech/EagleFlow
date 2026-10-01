-- Generated only from EagleFlow_Quick_Quote_Finalized_Mapping.xlsx (Products sheet).
-- Product UUIDs are intentionally resolved at apply time by normalized product code.

CREATE TEMP TABLE quick_quote_product_mapping_seed_source (
  normalized_product_code text NOT NULL,
  status text NOT NULL,
  section text,
  role_key text,
  strength_area text,
  load_type text,
  movement_key text,
  family_key text,
  plate_weight_kg numeric,
  station_count integer,
  selection_priority integer NOT NULL,
  upgrade_priority integer NOT NULL
);

INSERT INTO quick_quote_product_mapping_seed_source (
  normalized_product_code,
  status,
  section,
  role_key,
  strength_area,
  load_type,
  movement_key,
  family_key,
  plate_weight_kg,
  station_count,
  selection_priority,
  upgrade_priority
)
VALUES
  ('PR432', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PR536', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PR159', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('FTR30', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('FX0KLB', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('FXR02Y', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('FXR01W', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('FX00EG', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('FXT03Y', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('FXT02B', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('FXT01W', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PRM-1013', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('PRM-1007G', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('PRM-1008G', 'eligible', 'strength', 'seated_row', 'back', 'pin_loaded', 'seated_row', NULL, NULL, NULL, 100, 100),
  ('PRM-1009G', 'eligible', 'strength', 'biceps_curl', 'arms', 'pin_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('PRM-1005G', 'eligible', 'strength', 'chest_press', 'chest', 'pin_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('PRM-1004G', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'pin_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('PRM-1002G', 'eligible', 'strength', 'incline_press', 'chest', 'pin_loaded', 'incline_press', NULL, NULL, NULL, 100, 100),
  ('PRM-1002', 'eligible', 'strength', 'incline_press', 'chest', 'plate_loaded', 'incline_press', NULL, NULL, NULL, 100, 100),
  ('PRM-1009', 'eligible', 'strength', 'biceps_curl', 'arms', 'plate_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('PRM-1005', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('PRM-1012', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('PNT-1013', 'eligible', 'multifunction', 'smith_machine', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PRM-1007', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('PRM-1004', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'plate_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('PRM-1008', 'eligible', 'strength', 'seated_row', 'back', 'plate_loaded', 'seated_row', NULL, NULL, NULL, 100, 100),
  ('PNT-1012', 'eligible', 'multifunction', 'smith_machine', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('LJ-5003-M04', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('LJ-5003-M11', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('LJ-5003-M05', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('LJ-5003-M08', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('LJ-5003-M10', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('LJ-5003-M06', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('LJ-5003-M09', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('LJ-5003-M03', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('LJ-5003-M07', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('LJ-5003C', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 16, 100, 100),
  ('LJ-5006', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('LJ-5003A', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 8, 100, 100),
  ('LJ-5003', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 8, 100, 100),
  ('LJ-5004', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 5, 100, 100),
  ('LJ-5003-M01', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('LJ-5003-M02', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('LJ-5005', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 4, 100, 100),
  ('LJ-5003B', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 12, 100, 100),
  ('RS-3021', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('LJ-5002', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('RS-3022', 'eligible', 'strength', 'calf_raise', 'legs', 'plate_loaded', 'calf_raise', NULL, NULL, NULL, 100, 100),
  ('RS-3027', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'plate_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('RS-3026', 'eligible', 'strength', 'triceps_extension', 'arms', 'plate_loaded', 'triceps_extension', NULL, NULL, NULL, 100, 100),
  ('RS-3020', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'plate_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('RS-4002', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('RS-4017', 'eligible', 'strength', 'abdominal', 'core', 'plate_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('RS-3009', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('RS-3012', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('RS-3004', 'eligible', 'strength', 'incline_press', 'chest', 'plate_loaded', 'incline_press', NULL, NULL, NULL, 100, 100),
  ('RS-3011', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('RS-3018', 'eligible', 'strength', 'high_row', 'back', 'plate_loaded', 'high_row', NULL, NULL, NULL, 100, 100),
  ('RS-3003', 'eligible', 'strength', 'decline_chest_press', 'chest', 'plate_loaded', 'decline_chest_press', NULL, NULL, NULL, 100, 100),
  ('RS-3014', 'eligible', 'strength', 'low_row', 'back', 'plate_loaded', 'low_row', NULL, NULL, NULL, 100, 100),
  ('RS-3013', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('RS-3005', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('RS-1013', 'eligible', 'strength', 'glute_drive', 'glutes', 'plate_loaded', 'glute_drive', NULL, NULL, NULL, 100, 100),
  ('RS-1012B', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'plate_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100),
  ('RS-1011', 'eligible', 'strength', 'hip_thrust', 'glutes', 'plate_loaded', 'hip_thrust', NULL, NULL, NULL, 100, 100),
  ('RS-3001', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('RS-3002', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('RS-1005', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('RS-1008', 'eligible', 'strength', 'hip_extension', 'glutes', 'plate_loaded', 'hip_extension', NULL, NULL, NULL, 100, 100),
  ('RS-1010', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'plate_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100),
  ('RS-1009', 'eligible', 'strength', 'pendulum_squat', 'legs', 'plate_loaded', 'pendulum_squat', NULL, NULL, NULL, 100, 100),
  ('RS-1001B', 'eligible', 'strength', 'glute_drive', 'glutes', 'plate_loaded', 'glute_drive', NULL, NULL, NULL, 100, 100),
  ('RS-1006', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('RS-1007', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('RS-1002', 'eligible', 'strength', 'hack_squat', 'legs', 'plate_loaded', 'hack_squat', NULL, NULL, NULL, 100, 100),
  ('HM-3021', 'eligible', 'strength', 'abdominal', 'core', 'pin_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('HM-5006', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-5002', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-3022', 'eligible', 'strength', 'back_extension', 'back', 'pin_loaded', 'back_extension', NULL, NULL, NULL, 100, 100),
  ('HM-5003', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-5004', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-5001', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-3020', 'eligible', 'strength', 'leg_curl', 'legs', 'pin_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('RS-1001A', 'eligible', 'strength', 'glute_drive', 'glutes', 'plate_loaded', 'glute_drive', NULL, NULL, NULL, 100, 100),
  ('HM-3010', 'eligible', 'strength', 'leg_curl', 'legs', 'pin_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('HM-3018', 'eligible', 'strength', 'glute_machine', 'glutes', 'pin_loaded', 'glute_machine', NULL, NULL, NULL, 100, 100),
  ('HM-3013', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('HM-3017', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'pin_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100),
  ('HM-3015', 'eligible', 'strength', 'pec_fly', 'chest', 'pin_loaded', 'pec_fly', NULL, NULL, NULL, 100, 100),
  ('HM-3014', 'eligible', 'strength', 'lateral_raise', 'shoulder', 'pin_loaded', 'lateral_raise', NULL, NULL, NULL, 100, 100),
  ('HM-3016', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-3011', 'eligible', 'strength', 'leg_press', 'legs', 'pin_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('HM-3012', 'eligible', 'strength', 'calf_raise', 'legs', 'pin_loaded', 'calf_raise', NULL, NULL, NULL, 100, 100),
  ('HM-3008', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'pin_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100),
  ('HM-3005', 'eligible', 'strength', 'seated_row', 'back', 'pin_loaded', 'seated_row', NULL, NULL, NULL, 100, 100),
  ('HM-3006', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'pin_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('HM-3004', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('HM-3009', 'eligible', 'strength', 'leg_extension', 'legs', 'pin_loaded', 'leg_extension', NULL, NULL, NULL, 100, 100),
  ('HM-3002', 'eligible', 'strength', 'biceps_curl', 'arms', 'pin_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('HM-3007', 'eligible', 'strength', 'triceps_extension', 'arms', 'pin_loaded', 'triceps_extension', NULL, NULL, NULL, 100, 100),
  ('HM-3003', 'eligible', 'strength', 'chest_press', 'chest', 'pin_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('HM-2023', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2022', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2015', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2014', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2021', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-3001', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2017', 'eligible', 'dumbbell_rack', 'dumbbell_rack', NULL, NULL, NULL, 'burnsport_dumbbell', NULL, NULL, 100, 100),
  ('HM-2006', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2010', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2009C', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2008', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2009B', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2007', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2013', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2011', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-1047', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('HM-2005', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-1048', 'eligible', 'multifunction', 'smith_machine', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-1052', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('HM-1049', 'eligible', 'multifunction', 'smith_machine', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2001', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-2002', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-1044', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-1041', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-1045', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-1038-B', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('HM-1039', 'eligible', 'strength', 'leg_extension', 'legs', 'plate_loaded', 'leg_extension', NULL, NULL, NULL, 100, 100),
  ('HM-1034', 'eligible', 'strength', 'calf_raise', 'legs', 'plate_loaded', 'calf_raise', NULL, NULL, NULL, 100, 100),
  ('HM-1035', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('HM-1038', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('HM-1040', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-1030', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('HM-1031', 'eligible', 'strength', 'leg_extension', 'legs', 'plate_loaded', 'leg_extension', NULL, NULL, NULL, 100, 100),
  ('HM-1028', 'eligible', 'strength', 'glute_drive', 'glutes', 'plate_loaded', 'glute_drive', NULL, NULL, NULL, 100, 100),
  ('HM-1029', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('HM-1027', 'eligible', 'strength', 'leg_curl', 'legs', 'plate_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('HM-1032', 'eligible', 'strength', 'leg_curl', 'legs', 'plate_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('HM-1021', 'eligible', 'strength', 't_bar_row', 'back', 'plate_loaded', 't_bar_row', NULL, NULL, NULL, 100, 100),
  ('HM-1024', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('HM-1025', 'eligible', 'strength', 'calf_raise', 'legs', 'plate_loaded', 'calf_raise', NULL, NULL, NULL, 100, 100),
  ('HM-1026B', 'eligible', 'strength', 'hack_squat', 'legs', 'plate_loaded', 'hack_squat', NULL, NULL, NULL, 100, 100),
  ('HM-1023', 'eligible', 'strength', 'abdominal', 'core', 'plate_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('HM-1024B', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('HM-1026', 'eligible', 'strength', 'hack_squat', 'legs', 'plate_loaded', 'hack_squat', NULL, NULL, NULL, 100, 100),
  ('HM-1018', 'eligible', 'strength', 'high_row', 'back', 'plate_loaded', 'high_row', NULL, NULL, NULL, 100, 100),
  ('HM-1018B', 'eligible', 'strength', 'high_row', 'back', 'plate_loaded', 'high_row', NULL, NULL, NULL, 100, 100),
  ('HM-1020', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'plate_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('HM-1012', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('HM-1011', 'eligible', 'strength', 'iso_lateral_chest_back', 'chest', 'plate_loaded', 'iso_lateral_chest_back', NULL, NULL, NULL, 100, 100),
  ('HM-1013', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('HM-1016', 'eligible', 'strength', 'triceps_extension', 'arms', 'plate_loaded', 'triceps_extension', NULL, NULL, NULL, 100, 100),
  ('HM-1015', 'eligible', 'strength', 'biceps_curl', 'arms', 'plate_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('HM-1014', 'eligible', 'strength', 'low_row', 'back', 'plate_loaded', 'low_row', NULL, NULL, NULL, 100, 100),
  ('HM-1017', 'eligible', 'strength', 'pullover', 'back', 'plate_loaded', 'pullover', NULL, NULL, NULL, 100, 100),
  ('HM-1010', 'eligible', 'strength', 'lateral_raise', 'shoulder', 'plate_loaded', 'lateral_raise', NULL, NULL, NULL, 100, 100),
  ('HM-1005', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-1008', 'eligible', 'strength', 'wide_chest_press', 'chest', 'plate_loaded', 'wide_chest_press', NULL, NULL, NULL, 100, 100),
  ('HM-1009', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('HM-1004', 'eligible', 'strength', 'incline_press', 'chest', 'plate_loaded', 'incline_press', NULL, NULL, NULL, 100, 100),
  ('HM-1003', 'eligible', 'strength', 'decline_chest_press', 'chest', 'plate_loaded', 'decline_chest_press', NULL, NULL, NULL, 100, 100),
  ('HM-1007', 'eligible', 'strength', 'incline_press', 'chest', 'plate_loaded', 'incline_press', NULL, NULL, NULL, 100, 100),
  ('HM-1002', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('HM-1001', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('CD-003', 'eligible', 'cardio', 'cross_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('CD-005', 'eligible', 'cardio', 'upright_bike', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('CD-006', 'eligible', 'cardio', 'spinning_bike', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('CD-004', 'eligible', 'cardio', 'recumbent_bike', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('CD-007', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('CD-008', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('CD-002', 'eligible', 'cardio', 'cross_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('CD-001', 'eligible', 'cardio', 'treadmill', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('BRN-004-5', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'burnsport_rubber_weight_plates', 20, NULL, 100, 100),
  ('BRN-003-5', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'burnsport_pu_weight_plates', 20, NULL, 100, 100),
  ('BRN-004-2', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'burnsport_rubber_weight_plates', 5, NULL, 100, 100),
  ('BRN-004-4', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('BRN-004-3', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'burnsport_rubber_weight_plates', 10, NULL, 100, 100),
  ('BRN-003-4', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('BRN-004', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'burnsport_rubber_weight_plates', 2.5, NULL, 100, 100),
  ('BRN-003-3', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'burnsport_pu_weight_plates', 10, NULL, 100, 100),
  ('BRN-003', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'burnsport_pu_weight_plates', 2.5, NULL, 100, 100),
  ('BRN-003-2', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'burnsport_pu_weight_plates', 5, NULL, 100, 100),
  ('BRN-001-2', 'eligible', 'dumbbell', 'dumbbell_full_set', NULL, NULL, NULL, 'burnsport_dumbbell', NULL, NULL, 100, 100),
  ('BRN-002-2', 'eligible', 'dumbbell', 'dumbbell_full_set', NULL, NULL, NULL, 'burnsport_dumbbell', NULL, NULL, 100, 100),
  ('BRN-002-1', 'eligible', 'dumbbell', 'dumbbell_half_set', NULL, NULL, NULL, 'burnsport_dumbbell', NULL, NULL, 100, 100),
  ('BRN-001-1', 'eligible', 'dumbbell', 'dumbbell_half_set', NULL, NULL, NULL, 'burnsport_dumbbell', NULL, NULL, 100, 100),
  ('L119', 'eligible', 'dumbbell_rack', 'dumbbell_rack', NULL, NULL, NULL, 'premier_dumbbell', NULL, NULL, 100, 100),
  ('7715EA', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('B32001', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('E30901', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('L108', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('R30901', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('L133', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('6835TA-LED', 'eligible', 'cardio', 'treadmill', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('7130EA', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('7130TA', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('6835TA', 'eligible', 'cardio', 'treadmill', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('E38001', 'eligible', 'cardio', 'cross_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('R12001', 'eligible', 'cardio', 'recumbent_bike', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('6750EA', 'eligible', 'cardio', 'treadmill', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('B12101', 'eligible', 'cardio', 'upright_bike', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK9101', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK1814A', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK1805', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK1813A', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK8102', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK1801', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK1808', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK1813', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK1683', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1811', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK1930B-1', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK1683-L', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK0045', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK1821B', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1035E', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK1752', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK0016A', 'eligible', 'dumbbell_rack', 'dumbbell_rack', NULL, NULL, NULL, 'premier_dumbbell', NULL, NULL, 100, 100),
  ('OK8105', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK8101', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0038', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1925', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0029B', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM5006', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM5041', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0049E-2', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM9100F', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM9100B', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0049', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1116E', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1219A-7', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0049B-4', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1219A-6', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM5052C', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1219A-9', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1219A-8', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1219A-10', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0023', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1908', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1219A-4', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1219A', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1218B-6', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1218B-7', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1218B-10', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1219A-5', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1218B-5', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1218B', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1218B-4', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1218B-9', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1218B-8', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1221H-10', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0080B', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1221H-7', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1221H-4', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1221H-5', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1221H-8', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1223C-15', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1221H-6', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1221H-9', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1223C-20', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0026', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1221H', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1222C-15', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1223C', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1222C-20', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1223C-10', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1222C', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1204', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1384', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1201', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1222C-10', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1102', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6030', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1103A', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6021', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6016', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0005', 'eligible', 'dumbbell_rack', 'dumbbell_rack', NULL, NULL, NULL, 'premier_dumbbell', NULL, NULL, 100, 100),
  ('PM6003-2', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6017', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1101', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PMMB001-005', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6022', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1001A', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6005', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6012', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6027', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6019', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6018', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6009', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6088F', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6015', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6007', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM6026', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0029', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('OK5003-6', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1951', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM5003-1', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM5004-2', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PMMB009', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1307', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1317', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM5004-1', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1009', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0034', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1003', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0011C', 'eligible', 'dumbbell_rack', 'dumbbell_rack', NULL, NULL, NULL, 'premier_dumbbell', NULL, NULL, 100, 100),
  ('PM0033', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1005', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2009B', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2006-2-20', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2006-2-15', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2042B', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0041', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM0081A', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2006-2-25', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2006-2', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2006-2-10', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2005C-10', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'premier_rubber_weight_plates', 10, NULL, 100, 100),
  ('PM2005C-5', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'premier_rubber_weight_plates', 5, NULL, 100, 100),
  ('PM2030C-25', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2005C-20', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'premier_rubber_weight_plates', 20, NULL, 100, 100),
  ('PM2037B', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2005C-25', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2005C-15', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2005', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2005C', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'premier_rubber_weight_plates', 2.5, NULL, 100, 100),
  ('PM3015', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2030C-20', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'premier_tpu_weight_plates', 20, NULL, 100, 100),
  ('PM2030C-15', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM2030C-10', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'premier_tpu_weight_plates', 10, NULL, 100, 100),
  ('PM3015-250', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PM1012-50', 'eligible', 'dumbbell', 'dumbbell_full_set', NULL, NULL, NULL, 'premier_dumbbell', NULL, NULL, 100, 100),
  ('PM2030C', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'premier_tpu_weight_plates', 2.5, NULL, 100, 100),
  ('PM2030C-5', 'eligible', 'weight_plate', 'weight_plate', NULL, NULL, NULL, 'premier_tpu_weight_plates', 5, NULL, 100, 100),
  ('PM1036-50', 'eligible', 'dumbbell', 'dumbbell_full_set', NULL, NULL, NULL, 'premier_dumbbell', NULL, NULL, 100, 100),
  ('PM1036', 'eligible', 'dumbbell', 'dumbbell_half_set', NULL, NULL, NULL, 'premier_dumbbell', NULL, NULL, 100, 100),
  ('PM1012', 'eligible', 'dumbbell', 'dumbbell_half_set', NULL, NULL, NULL, 'premier_dumbbell', NULL, NULL, 100, 100),
  ('PM1036G-50', 'eligible', 'dumbbell', 'dumbbell_full_set', NULL, NULL, NULL, 'premier_dumbbell', NULL, NULL, 100, 100),
  ('PM1012A-50', 'eligible', 'dumbbell', 'dumbbell_full_set', NULL, NULL, NULL, 'premier_dumbbell', NULL, NULL, 100, 100),
  ('PM1012A', 'eligible', 'dumbbell', 'dumbbell_half_set', NULL, NULL, NULL, 'premier_dumbbell', NULL, NULL, 100, 100),
  ('PM1036G', 'eligible', 'dumbbell', 'dumbbell_half_set', NULL, NULL, NULL, 'premier_dumbbell', NULL, NULL, 100, 100),
  ('TQL75', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL60', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL40', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('TQL58', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL55', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL50', 'eligible', 'strength', 'torso_oblique', 'core', 'plate_loaded', 'torso_oblique', NULL, NULL, NULL, 100, 100),
  ('TQL79', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL47', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL36', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('TQL52', 'eligible', 'strength', 'biceps_curl', 'arms', 'plate_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('TQL46', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL73', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL45', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL44', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('TQL38', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('TQL69', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL62', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL37', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('TQL41', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL78', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL59', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL56', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('TQL54', 'eligible', 'strength', 'vertical_knee_raise', 'core', 'plate_loaded', 'vertical_knee_raise', NULL, NULL, NULL, 100, 100),
  ('TQL70', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL51', 'eligible', 'strength', 'torso_oblique', 'core', 'plate_loaded', 'torso_oblique', NULL, NULL, NULL, 100, 100),
  ('TQL74', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL49', 'eligible', 'strength', 'abdominal', 'core', 'plate_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('TQL77', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL42', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('TQL72', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL68', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL66', 'eligible', 'strength', 'abdominal', 'core', 'plate_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('TQL43', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL61', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL48', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL39', 'eligible', 'strength', 'hip_thrust', 'glutes', 'plate_loaded', 'hip_thrust', NULL, NULL, NULL, 100, 100),
  ('TQL64', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL65', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL71', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL76', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL67', 'eligible', 'strength', 'pec_fly', 'chest', 'plate_loaded', 'pec_fly', NULL, NULL, NULL, 100, 100),
  ('TQL35', 'eligible', 'strength', 'calf_raise', 'legs', 'plate_loaded', 'calf_raise', NULL, NULL, NULL, 100, 100),
  ('TQL53', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('TQL57', 'eligible', 'strength', 'calf_raise', 'legs', 'plate_loaded', 'calf_raise', NULL, NULL, NULL, 100, 100),
  ('TQL63', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL10', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('TQN39', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 8, 100, 100),
  ('TQL11', 'eligible', 'strength', 'incline_press', 'chest', 'plate_loaded', 'incline_press', NULL, NULL, NULL, 100, 100),
  ('TQL09A', 'eligible', 'multifunction', 'smith_machine', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL16', 'eligible', 'strength', 'calf_raise', 'legs', 'plate_loaded', 'calf_raise', NULL, NULL, NULL, 100, 100),
  ('TQL13', 'eligible', 'strength', 'biceps_curl', 'arms', 'plate_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('TQL33', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('TQL18', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('TQL24', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('TQN33', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL32', 'eligible', 'strength', 'pullover', 'back', 'plate_loaded', 'pullover', NULL, NULL, NULL, 100, 100),
  ('TQN36', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 5, 100, 100),
  ('TQN34', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL15', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('TQL07', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('TQN32', 'eligible', 'multifunction', 'smith_machine', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL14', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'plate_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('TQL25', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('TQL34', 'eligible', 'strength', 'abdominal', 'core', 'plate_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('TQL09', 'eligible', 'multifunction', 'smith_machine', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL01', 'eligible', 'strength', 'incline_press', 'chest', 'plate_loaded', 'incline_press', NULL, NULL, NULL, 100, 100),
  ('TQN35', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 4, 100, 100),
  ('TQL20', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL17', 'eligible', 'strength', 'low_row', 'back', 'plate_loaded', 'low_row', NULL, NULL, NULL, 100, 100),
  ('TQL06', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('TQL08', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('TQL23', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('TQL27', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('TQL03', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('TQL21', 'eligible', 'strength', 'biceps_curl', 'arms', 'plate_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('TQL28', 'eligible', 'strength', 'pec_fly', 'chest', 'plate_loaded', 'pec_fly', NULL, NULL, NULL, 100, 100),
  ('TQL22', 'eligible', 'strength', 'leg_extension', 'legs', 'plate_loaded', 'leg_extension', NULL, NULL, NULL, 100, 100),
  ('TQL31', 'eligible', 'strength', 'triceps_extension', 'arms', 'plate_loaded', 'triceps_extension', NULL, NULL, NULL, 100, 100),
  ('TQN30E', 'eligible', 'multifunction', 'smith_machine', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL29', 'eligible', 'strength', 'lateral_raise', 'shoulder', 'plate_loaded', 'lateral_raise', NULL, NULL, NULL, 100, 100),
  ('TQN38', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 8, 100, 100),
  ('TQL30', 'eligible', 'strength', 'leg_curl', 'legs', 'plate_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('TQL02', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('TQL05', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQL19', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('TQL04', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('TQL12', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('TQN37', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 5, 100, 100),
  ('TQL26', 'eligible', 'strength', 'hack_squat', 'legs', 'plate_loaded', 'hack_squat', NULL, NULL, NULL, 100, 100),
  ('TQN31', 'eligible', 'multifunction', 'smith_machine', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQN05', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('TQN08', 'eligible', 'strength', 'biceps_curl', 'arms', 'pin_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('TQN24', 'eligible', 'strength', 'biceps_triceps', 'arms', 'pin_loaded', 'biceps_triceps', NULL, NULL, NULL, 100, 100),
  ('TQN13', 'eligible', 'strength', 'leg_curl', 'legs', 'pin_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('TQN03', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'pin_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('TQN17', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'pin_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100),
  ('TQN21', 'eligible', 'strength', 'leg_extension_curl', 'legs', 'pin_loaded', 'leg_extension_curl', NULL, NULL, NULL, 100, 100),
  ('TQN14', 'eligible', 'strength', 'leg_curl', 'legs', 'pin_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('TQN22', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'pin_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100),
  ('TQN07', 'eligible', 'strength', 'row', 'back', 'pin_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('TQN26', 'eligible', 'strength', 'abdominal', 'core', 'pin_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('TQN19', 'eligible', 'strength', 'abdominal', 'core', 'pin_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('TQN02', 'eligible', 'strength', 'pec_fly', 'chest', 'pin_loaded', 'pec_fly', NULL, NULL, NULL, 100, 100),
  ('EPN20', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQN06', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('TQN30', 'eligible', 'multifunction', 'smith_machine', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('EPN21', 'eligible', 'strength', 'biceps_triceps', 'arms', 'pin_loaded', 'biceps_triceps', NULL, NULL, NULL, 100, 100),
  ('TQN16', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'pin_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100),
  ('TQN18', 'eligible', 'strength', 'hip_machine', 'glutes', 'pin_loaded', 'hip_machine', NULL, NULL, NULL, 100, 100),
  ('TQN28', 'eligible', 'strength', 'rear_delt', 'shoulder', 'pin_loaded', 'rear_delt', NULL, NULL, NULL, 100, 100),
  ('TQN11', 'eligible', 'strength', 'leg_press', 'legs', 'pin_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('TQN15', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'pin_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100),
  ('TQN23', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('TQN20', 'eligible', 'strength', 'low_row', 'back', 'pin_loaded', 'low_row', NULL, NULL, NULL, 100, 100),
  ('TQN09', 'eligible', 'strength', 'triceps_extension', 'arms', 'pin_loaded', 'triceps_extension', NULL, NULL, NULL, 100, 100),
  ('TQN12', 'eligible', 'strength', 'leg_extension', 'legs', 'pin_loaded', 'leg_extension', NULL, NULL, NULL, 100, 100),
  ('TQN25', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('EPN22', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('EPN24', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'pin_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100),
  ('TQN29', 'eligible', 'strength', 'forearm_wrist_curl', 'arms', 'pin_loaded', 'forearm_wrist_curl', NULL, NULL, NULL, 100, 100),
  ('EPN23', 'eligible', 'strength', 'leg_curl', 'legs', 'pin_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('TQN01', 'eligible', 'strength', 'chest_press', 'chest', 'pin_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('TQN10', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('TQN27', 'eligible', 'strength', 'leg_extension_curl', 'legs', 'pin_loaded', 'leg_extension_curl', NULL, NULL, NULL, 100, 100),
  ('PXN-025', 'eligible', 'strength', 'abdominal', 'core', 'pin_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('TQN04', 'eligible', 'strength', 'lateral_raise', 'shoulder', 'pin_loaded', 'lateral_raise', NULL, NULL, NULL, 100, 100),
  ('EPN19', 'eligible', 'strength', 'torso_oblique', 'core', 'pin_loaded', 'torso_oblique', NULL, NULL, NULL, 100, 100),
  ('EPN09', 'eligible', 'strength', 'low_row', 'back', 'pin_loaded', 'low_row', NULL, NULL, NULL, 100, 100),
  ('EPN14', 'eligible', 'strength', 'leg_press', 'legs', 'pin_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('PXL53', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('EPN16', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'pin_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100),
  ('PXL56', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXL55', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('EPN05', 'eligible', 'strength', 'biceps_curl', 'arms', 'pin_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('PXL58', 'eligible', 'strength', 'abdominal', 'core', 'plate_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('PXL45', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('EPN02', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('EPN11', 'eligible', 'strength', 'leg_extension', 'legs', 'pin_loaded', 'leg_extension', NULL, NULL, NULL, 100, 100),
  ('EPN12', 'eligible', 'strength', 'leg_curl', 'legs', 'pin_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('EPN13', 'eligible', 'strength', 'leg_curl', 'legs', 'pin_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('PXL51', 'eligible', 'strength', 'abdominal', 'core', 'plate_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('PXL48', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('EPN17', 'eligible', 'strength', 'back_extension', 'back', 'pin_loaded', 'back_extension', NULL, NULL, NULL, 100, 100),
  ('PXL50', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXL52', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('EPN01', 'eligible', 'strength', 'chest_press', 'chest', 'pin_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('EPN18', 'eligible', 'strength', 'abdominal', 'core', 'pin_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('PXL46', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('EPN08', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('PXL47', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('EPN10', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('EPN03', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'pin_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('PXL49', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXL44', 'eligible', 'strength', 'hip_machine', 'glutes', 'plate_loaded', 'hip_machine', NULL, NULL, NULL, 100, 100),
  ('EPN15', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'pin_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100),
  ('EPN04', 'eligible', 'strength', 'lateral_raise', 'shoulder', 'pin_loaded', 'lateral_raise', NULL, NULL, NULL, 100, 100),
  ('PXL43', 'eligible', 'strength', 'abdominal', 'core', 'plate_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('PXL57', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXL42', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXL54', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('EPN06', 'eligible', 'strength', 'triceps_extension', 'arms', 'pin_loaded', 'triceps_extension', NULL, NULL, NULL, 100, 100),
  ('EPN07', 'eligible', 'strength', 'row', 'back', 'pin_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('PXL32', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('PXL23', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('PXL35', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('PXL04', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXL09', 'eligible', 'multifunction', 'smith_machine', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXL01', 'eligible', 'strength', 'incline_press', 'chest', 'plate_loaded', 'incline_press', NULL, NULL, NULL, 100, 100),
  ('PXL30', 'eligible', 'strength', 'triceps_extension', 'arms', 'plate_loaded', 'triceps_extension', NULL, NULL, NULL, 100, 100),
  ('PXL19', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('PXL25', 'eligible', 'strength', 'hip_thrust', 'glutes', 'plate_loaded', 'hip_thrust', NULL, NULL, NULL, 100, 100),
  ('PXL14', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'plate_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('PXL37', 'eligible', 'strength', 'back_pull', 'back', 'plate_loaded', 'back_pull', NULL, NULL, NULL, 100, 100),
  ('PXL36', 'eligible', 'strength', 'hack_squat', 'legs', 'plate_loaded', 'hack_squat', NULL, NULL, NULL, 100, 100),
  ('PXL26', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('PXL33', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('PXL22', 'eligible', 'strength', 'biceps_curl', 'arms', 'plate_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('PXL40', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXL34', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('PXL06', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('PXL24', 'eligible', 'strength', 'glute_machine', 'glutes', 'plate_loaded', 'glute_machine', NULL, NULL, NULL, 100, 100),
  ('PXL27', 'eligible', 'strength', 'back_pull', 'back', 'plate_loaded', 'back_pull', NULL, NULL, NULL, 100, 100),
  ('PXL03', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('PXL20', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('PXL38', 'eligible', 'strength', 'abdominal', 'core', 'plate_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('PXL05', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('PXL07', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('PXL17', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'plate_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('PXL12', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('PXL31', 'eligible', 'strength', 'pullover', 'back', 'plate_loaded', 'pullover', NULL, NULL, NULL, 100, 100),
  ('PXL39', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('PXL21', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('PXL29', 'eligible', 'strength', 'leg_curl', 'legs', 'plate_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('PXL16', 'eligible', 'strength', 'calf_raise', 'legs', 'plate_loaded', 'calf_raise', NULL, NULL, NULL, 100, 100),
  ('PXL10', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('PXL11', 'eligible', 'strength', 'incline_press', 'chest', 'plate_loaded', 'incline_press', NULL, NULL, NULL, 100, 100),
  ('PXL02', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('PXL08', 'eligible', 'multifunction', 'smith_machine', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXL41', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXL13', 'eligible', 'strength', 'biceps_curl', 'arms', 'plate_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('PXL15', 'eligible', 'strength', 'back_pull', 'back', 'plate_loaded', 'back_pull', NULL, NULL, NULL, 100, 100),
  ('PXL28', 'eligible', 'strength', 'pec_fly', 'chest', 'plate_loaded', 'pec_fly', NULL, NULL, NULL, 100, 100),
  ('PXL18', 'eligible', 'strength', 'low_row', 'back', 'plate_loaded', 'low_row', NULL, NULL, NULL, 100, 100),
  ('PXN05', 'eligible', 'strength', 'biceps_curl', 'arms', 'pin_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('PXN32D', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 4, 100, 100),
  ('PXN22', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('PXN08', 'eligible', 'strength', 'back_extension', 'back', 'pin_loaded', 'back_extension', NULL, NULL, NULL, 100, 100),
  ('PXN23', 'eligible', 'strength', 'leg_extension_curl', 'legs', 'pin_loaded', 'leg_extension_curl', NULL, NULL, NULL, 100, 100),
  ('PXN20', 'eligible', 'strength', 'biceps_triceps', 'arms', 'pin_loaded', 'biceps_triceps', NULL, NULL, NULL, 100, 100),
  ('PXN28', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXN34', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 5, 100, 100),
  ('PXN07', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXN06', 'eligible', 'strength', 'triceps_extension', 'arms', 'pin_loaded', 'triceps_extension', NULL, NULL, NULL, 100, 100),
  ('PXN24', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'pin_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100),
  ('PXN36', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 8, 100, 100),
  ('PXN13', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('PXN30', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXN10', 'eligible', 'strength', 'torso_oblique', 'core', 'pin_loaded', 'torso_oblique', NULL, NULL, NULL, 100, 100),
  ('PXN31', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 4, 100, 100),
  ('PXN09', 'eligible', 'strength', 'abdominal', 'core', 'pin_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('PXN17', 'eligible', 'strength', 'leg_extension', 'legs', 'pin_loaded', 'leg_extension', NULL, NULL, NULL, 100, 100),
  ('PXN11', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('PXN25', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXN26-A', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXN15', 'eligible', 'strength', 'leg_extension', 'legs', 'pin_loaded', 'leg_extension', NULL, NULL, NULL, 100, 100),
  ('PXN19', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'pin_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('PXN12', 'eligible', 'strength', 'horizontal_row', 'back', 'pin_loaded', 'horizontal_row', NULL, NULL, NULL, 100, 100),
  ('PXN32C', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 4, 100, 100),
  ('PXN35', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 8, 100, 100),
  ('PXN33', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 5, 100, 100),
  ('PXN14', 'eligible', 'strength', 'leg_curl', 'legs', 'pin_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('PXN16', 'eligible', 'strength', 'leg_press', 'legs', 'pin_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('PXN29', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXN27', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('PXN21', 'eligible', 'strength', 'abdominal', 'core', 'pin_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('PXN18', 'eligible', 'strength', 'calf_raise', 'legs', 'pin_loaded', 'calf_raise', NULL, NULL, NULL, 100, 100),
  ('PXN26', 'eligible', 'strength', 'squat', 'legs', 'pin_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('APL51', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APL30', 'eligible', 'strength', 'glute_drive', 'glutes', 'plate_loaded', 'glute_drive', NULL, NULL, NULL, 100, 100),
  ('APL34', 'eligible', 'strength', 't_bar_row', 'back', 'plate_loaded', 't_bar_row', NULL, NULL, NULL, 100, 100),
  ('APL49', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APL43', 'eligible', 'strength', 'hack_squat', 'legs', 'plate_loaded', 'hack_squat', NULL, NULL, NULL, 100, 100),
  ('APL28', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('PXN04', 'eligible', 'strength', 'seated_row', 'back', 'pin_loaded', 'seated_row', NULL, NULL, NULL, 100, 100),
  ('PXN03', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'pin_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('APL38', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'plate_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('APL36', 'eligible', 'strength', 'glute_machine', 'glutes', 'plate_loaded', 'glute_machine', NULL, NULL, NULL, 100, 100),
  ('APL42', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('APL29', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('APL54', 'eligible', 'strength', 'calf_raise', 'legs', 'plate_loaded', 'calf_raise', NULL, NULL, NULL, 100, 100),
  ('APL35', 'eligible', 'strength', 'glute_machine', 'glutes', 'plate_loaded', 'glute_machine', NULL, NULL, NULL, 100, 100),
  ('APL53', 'eligible', 'strength', 'vertical_knee_raise', 'core', 'plate_loaded', 'vertical_knee_raise', NULL, NULL, NULL, 100, 100),
  ('APL48', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APL37', 'eligible', 'strength', 'decline_chest_press', 'arms', 'plate_loaded', 'decline_chest_press', NULL, NULL, NULL, 100, 100),
  ('APL32', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APL50', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APL46', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APL47', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APL44', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('APL39', 'eligible', 'strength', 'back_extension', 'back', 'plate_loaded', 'back_extension', NULL, NULL, NULL, 100, 100),
  ('APL45', 'eligible', 'strength', 'incline_fly', 'chest', 'plate_loaded', 'incline_fly', NULL, NULL, NULL, 100, 100),
  ('APL52', 'eligible', 'strength', 'abdominal', 'core', 'plate_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('PXN01', 'eligible', 'strength', 'chest_press', 'chest', 'pin_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('APL31', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('APL33', 'eligible', 'strength', 'calf_raise', 'legs', 'plate_loaded', 'calf_raise', NULL, NULL, NULL, 100, 100),
  ('PXN02', 'eligible', 'strength', 'pec_fly', 'chest', 'pin_loaded', 'pec_fly', NULL, NULL, NULL, 100, 100),
  ('APL40', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APL41', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('APL21', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('APL16', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('APL09', 'eligible', 'strength', 'seated_row', 'back', 'plate_loaded', 'seated_row', NULL, NULL, NULL, 100, 100),
  ('APL14', 'eligible', 'strength', 'glute_machine', 'glutes', 'plate_loaded', 'glute_machine', NULL, NULL, NULL, 100, 100),
  ('APL11', 'eligible', 'strength', 'low_row', 'back', 'plate_loaded', 'low_row', NULL, NULL, NULL, 100, 100),
  ('APL24', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('APL12', 'eligible', 'strength', 'triceps_extension', 'arms', 'plate_loaded', 'triceps_extension', NULL, NULL, NULL, 100, 100),
  ('APL08', 'eligible', 'strength', 'leg_press', 'legs', 'plate_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('APL10', 'eligible', 'strength', 'leg_curl', 'legs', 'plate_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('APL07', 'eligible', 'strength', 'leg_extension', 'legs', 'plate_loaded', 'leg_extension', NULL, NULL, NULL, 100, 100),
  ('APL06', 'eligible', 'strength', 'incline_press', 'chest', 'plate_loaded', 'incline_press', NULL, NULL, NULL, 100, 100),
  ('APL18', 'eligible', 'strength', 'pullover', 'back', 'plate_loaded', 'pullover', NULL, NULL, NULL, 100, 100),
  ('APL15', 'eligible', 'strength', 'glute_drive', 'glutes', 'plate_loaded', 'glute_drive', NULL, NULL, NULL, 100, 100),
  ('APL19', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('APL13', 'eligible', 'strength', 'biceps_curl', 'arms', 'plate_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('APL23', 'eligible', 'strength', 't_bar_row', 'back', 'plate_loaded', 't_bar_row', NULL, NULL, NULL, 100, 100),
  ('APL20', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('APL25', 'eligible', 'strength', 'squat', 'legs', 'plate_loaded', 'squat', NULL, NULL, NULL, 100, 100),
  ('APL27', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('APL26', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'plate_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100),
  ('APL17', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('APL05', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'plate_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('APL22', 'eligible', 'strength', 'leg_curl', 'legs', 'plate_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('APN20', 'eligible', 'strength', 'leg_extension', 'legs', 'pin_loaded', 'leg_extension', NULL, NULL, NULL, 100, 100),
  ('APL01', 'eligible', 'multifunction', 'smith_machine', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APN42', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 5, 100, 100),
  ('APN37', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APN39', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 4, 100, 100),
  ('APN36', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APN31', 'eligible', 'strength', 'hip_thrust', 'glutes', 'pin_loaded', 'hip_thrust', NULL, NULL, NULL, 100, 100),
  ('APN22', 'eligible', 'strength', 'back_machine', 'back', 'pin_loaded', 'back_machine', NULL, NULL, NULL, 100, 100),
  ('APN38', 'eligible', 'multifunction', 'functional_trainer', NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APN43', 'eligible', 'strength', 'torso_oblique', 'core', 'pin_loaded', 'torso_oblique', NULL, NULL, NULL, 100, 100),
  ('APN27', 'eligible', 'strength', 'triceps_extension', 'arms', 'pin_loaded', 'triceps_extension', NULL, NULL, NULL, 100, 100),
  ('APN32', 'eligible', 'strength', 'back_extension', 'back', 'pin_loaded', 'back_extension', NULL, NULL, NULL, 100, 100),
  ('APN30', 'eligible', 'strength', 'abdominal', 'core', 'pin_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('APN26', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APN35', 'eligible', 'strength', 'chest_press', 'chest', 'pin_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('APN25', 'eligible', 'strength', 'glute_machine', 'glutes', 'pin_loaded', 'glute_machine', NULL, NULL, NULL, 100, 100),
  ('APN41', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 2, 100, 100),
  ('APN23', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APN44', 'eligible', 'strength', 'abdominal', 'core', 'pin_loaded', 'abdominal', NULL, NULL, NULL, 100, 100),
  ('APN29', 'eligible', 'strength', 'hip_thrust', 'glutes', 'pin_loaded', 'hip_thrust', NULL, NULL, NULL, 100, 100),
  ('APL04', 'eligible', 'strength', 'lat_pulldown', 'back', 'plate_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('APN33', 'eligible', 'strength', 'hip_thrust', 'glutes', 'pin_loaded', 'hip_thrust', NULL, NULL, NULL, 100, 100),
  ('APN21', 'eligible', 'strength', 'leg_curl', 'legs', 'pin_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('APN18', 'eligible', 'strength', 'biceps_curl', 'arms', 'pin_loaded', 'biceps_curl', NULL, NULL, NULL, 100, 100),
  ('APN17', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('APN34', 'eligible', 'strength', 'glute_kickback', 'glutes', 'pin_loaded', 'glute_kickback', NULL, NULL, NULL, 100, 100),
  ('APN28', 'eligible', 'strength', 'glute_kickback', 'glutes', 'pin_loaded', 'glute_kickback', NULL, NULL, NULL, 100, 100),
  ('APN19', 'eligible', 'strength', 'triceps_extension', 'arms', 'pin_loaded', 'triceps_extension', NULL, NULL, NULL, 100, 100),
  ('APL03', 'eligible', 'strength', 'chest_press', 'chest', 'plate_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('APL02', 'eligible', 'strength', 'row', 'back', 'plate_loaded', 'row', NULL, NULL, NULL, 100, 100),
  ('APN24', 'eligible', 'strength', 'lateral_raise', 'shoulder', 'pin_loaded', 'lateral_raise', NULL, NULL, NULL, 100, 100),
  ('APN40', 'eligible', 'multifunction', 'multi_station', NULL, NULL, NULL, NULL, NULL, 8, 100, 100),
  ('APN09', 'eligible', 'strength', 'leg_press', 'legs', 'pin_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('APN07', 'eligible', 'strength', 'biceps_triceps', 'arms', 'pin_loaded', 'biceps_triceps', NULL, NULL, NULL, 100, 100),
  ('APN14', 'eligible', 'strength', 'chest_press', 'chest', 'pin_loaded', 'chest_press', NULL, NULL, NULL, 100, 100),
  ('APN11', 'eligible', 'strength', 'horizontal_row', 'back', 'pin_loaded', 'horizontal_row', NULL, NULL, NULL, 100, 100),
  ('APN10', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APN06', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APN15', 'eligible', 'strength', 'seated_row', 'back', 'pin_loaded', 'seated_row', NULL, NULL, NULL, 100, 100),
  ('APN08', 'eligible', 'strength', 'leg_press', 'legs', 'pin_loaded', 'leg_press', NULL, NULL, NULL, 100, 100),
  ('APN04', 'manual_excluded', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 100),
  ('APN13', 'eligible', 'strength', 'hip_machine', 'glutes', 'pin_loaded', 'hip_machine', NULL, NULL, NULL, 100, 100),
  ('APN02', 'eligible', 'strength', 'leg_extension_curl', 'legs', 'pin_loaded', 'leg_extension_curl', NULL, NULL, NULL, 100, 100),
  ('APN05-A', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('APN03', 'eligible', 'strength', 'leg_extension_curl', 'legs', 'pin_loaded', 'leg_extension_curl', NULL, NULL, NULL, 100, 100),
  ('APN05', 'eligible', 'strength', 'lat_pulldown', 'back', 'pin_loaded', 'lat_pulldown', NULL, NULL, NULL, 100, 100),
  ('APN16', 'eligible', 'strength', 'shoulder_press', 'shoulder', 'pin_loaded', 'shoulder_press', NULL, NULL, NULL, 100, 100),
  ('APN05-B', 'eligible', 'strength', 'seated_row', 'back', 'pin_loaded', 'seated_row', NULL, NULL, NULL, 100, 100),
  ('APN12', 'eligible', 'strength', 'calf_raise', 'legs', 'pin_loaded', 'calf_raise', NULL, NULL, NULL, 100, 100),
  ('APN03-A', 'eligible', 'strength', 'leg_curl', 'legs', 'pin_loaded', 'leg_curl', NULL, NULL, NULL, 100, 100),
  ('APN01', 'eligible', 'strength', 'hip_abductor_adductor', 'glutes', 'pin_loaded', 'hip_abductor_adductor', NULL, NULL, NULL, 100, 100);

DO $quick_quote_seed_preflight$
DECLARE
  actual_count bigint;
BEGIN
  SELECT count(*) INTO actual_count
  FROM public.products
  WHERE is_active IS TRUE AND deleted_at IS NULL;
  IF actual_count <> 683 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: expected 683 active products, found %', actual_count;
  END IF;

  SELECT count(*) INTO actual_count FROM quick_quote_product_mapping_seed_source;
  IF actual_count <> 683 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: expected 683 source rows, found %', actual_count;
  END IF;

  SELECT count(*) - count(DISTINCT normalized_product_code) INTO actual_count
  FROM quick_quote_product_mapping_seed_source;
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: found % duplicate normalized source codes', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM quick_quote_product_mapping_seed_source AS source
  LEFT JOIN public.products AS product
    ON product.normalized_product_code = source.normalized_product_code
  WHERE product.id IS NULL;
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: % mapping codes resolve to zero products', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM (
    SELECT source.normalized_product_code
    FROM quick_quote_product_mapping_seed_source AS source
    JOIN public.products AS product
      ON product.normalized_product_code = source.normalized_product_code
    GROUP BY source.normalized_product_code
    HAVING count(*) <> 1
  ) AS ambiguous_codes;
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: % mapping codes resolve to multiple products', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM public.products AS product
  LEFT JOIN quick_quote_product_mapping_seed_source AS source
    ON source.normalized_product_code = product.normalized_product_code
  WHERE product.is_active IS TRUE
    AND product.deleted_at IS NULL
    AND source.normalized_product_code IS NULL;
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: % active products lack a mapping', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM quick_quote_product_mapping_seed_source AS source
  JOIN public.products AS product
    ON product.normalized_product_code = source.normalized_product_code
  WHERE product.is_active IS DISTINCT FROM TRUE OR product.deleted_at IS NOT NULL;
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: % mappings target inactive or deleted products', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM quick_quote_product_mapping_seed_source
  WHERE status = 'eligible';
  IF actual_count <> 434 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: expected 434 eligible rows, found %', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM quick_quote_product_mapping_seed_source
  WHERE status = 'manual_excluded';
  IF actual_count <> 249 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: expected 249 manual_excluded rows, found %', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM quick_quote_product_mapping_seed_source
  WHERE status NOT IN ('eligible', 'manual_excluded');
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: found % unresolved rows', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM quick_quote_product_mapping_seed_source
  WHERE status = 'eligible' AND (section IS NULL OR role_key IS NULL);
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: % eligible rows lack section or role_key', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM quick_quote_product_mapping_seed_source
  WHERE status = 'eligible'
    AND section = 'cardio'
    AND role_key NOT IN ('treadmill', 'cross_trainer', 'recumbent_bike', 'upright_bike', 'spinning_bike');
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: % eligible cardio rows have an unapproved role', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM quick_quote_product_mapping_seed_source
  WHERE status = 'eligible'
    AND section = 'strength'
    AND (strength_area IS NULL OR load_type IS NULL OR movement_key IS NULL);
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: % eligible strength rows lack area, load type, or movement key', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM quick_quote_product_mapping_seed_source
  WHERE status = 'eligible'
    AND section = 'multifunction'
    AND (
      role_key NOT IN ('smith_machine', 'functional_trainer', 'multi_station')
      OR (role_key = 'multi_station' AND (station_count IS NULL OR station_count <= 0))
      OR (role_key <> 'multi_station' AND station_count IS NOT NULL)
    );
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: % multifunction rows violate role/station rules', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM quick_quote_product_mapping_seed_source
  WHERE status = 'eligible'
    AND section = 'weight_plate'
    AND (role_key <> 'weight_plate' OR family_key IS NULL OR plate_weight_kg NOT IN (2.5, 5, 10, 20));
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: % weight-plate rows violate role/family/weight rules', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM (
    SELECT family_key
    FROM quick_quote_product_mapping_seed_source
    WHERE status = 'eligible' AND section = 'weight_plate'
    GROUP BY family_key
    HAVING count(DISTINCT plate_weight_kg) <> 4
      OR count(*) FILTER (WHERE plate_weight_kg IN (2.5, 5, 10, 20)) <> 4
  ) AS incomplete_plate_families;
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: found % incomplete automatic plate families', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM (
    SELECT family_key
    FROM quick_quote_product_mapping_seed_source
    WHERE status = 'eligible' AND section IN ('dumbbell', 'dumbbell_rack')
    GROUP BY family_key
    HAVING count(*) FILTER (WHERE role_key = 'dumbbell_full_set') = 0
      OR count(*) FILTER (WHERE role_key = 'dumbbell_half_set') = 0
      OR count(*) FILTER (WHERE role_key = 'dumbbell_rack') = 0
  ) AS incomplete_dumbbell_families;
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: found % incompatible dumbbell set/rack families', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM quick_quote_product_mapping_seed_source
  WHERE section = 'strength'
    AND (
      (normalized_product_code LIKE 'APN%' AND load_type <> 'pin_loaded')
      OR (normalized_product_code LIKE 'APL%' AND load_type <> 'plate_loaded')
      OR (normalized_product_code LIKE 'PXN%' AND load_type <> 'pin_loaded')
      OR (normalized_product_code LIKE 'PXL%' AND load_type <> 'plate_loaded')
      OR (normalized_product_code LIKE 'EPN%' AND load_type <> 'pin_loaded')
      OR (normalized_product_code LIKE 'TQN%' AND load_type <> 'pin_loaded')
      OR (normalized_product_code LIKE 'TQL%' AND load_type <> 'plate_loaded')
    );
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: % approved-prefix strength rows have a load mismatch', actual_count;
  END IF;

  SELECT count(*) INTO actual_count FROM public.quick_quote_product_mappings;
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed aborted: target table must be empty, found % rows', actual_count;
  END IF;
END;
$quick_quote_seed_preflight$;

INSERT INTO public.quick_quote_product_mappings (
  product_id,
  status,
  section,
  role_key,
  strength_area,
  load_type,
  movement_key,
  family_key,
  plate_weight_kg,
  station_count,
  selection_priority,
  upgrade_priority
)
SELECT
  product.id,
  source.status,
  source.section,
  source.role_key,
  source.strength_area,
  source.load_type,
  source.movement_key,
  source.family_key,
  source.plate_weight_kg,
  source.station_count,
  source.selection_priority,
  source.upgrade_priority
FROM quick_quote_product_mapping_seed_source AS source
JOIN public.products AS product
  ON product.normalized_product_code = source.normalized_product_code
WHERE product.is_active IS TRUE
  AND product.deleted_at IS NULL
ORDER BY source.normalized_product_code;

DO $quick_quote_seed_postcheck$
DECLARE
  actual_count bigint;
BEGIN
  SELECT count(*) INTO actual_count FROM public.quick_quote_product_mappings;
  IF actual_count <> 683 THEN
    RAISE EXCEPTION 'Quick Quote seed postcheck failed: expected 683 rows, found %', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM public.quick_quote_product_mappings
  WHERE status = 'eligible';
  IF actual_count <> 434 THEN
    RAISE EXCEPTION 'Quick Quote seed postcheck failed: expected 434 eligible rows, found %', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM public.quick_quote_product_mappings
  WHERE status = 'manual_excluded';
  IF actual_count <> 249 THEN
    RAISE EXCEPTION 'Quick Quote seed postcheck failed: expected 249 manual_excluded rows, found %', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM public.quick_quote_product_mappings
  WHERE status = 'eligible' AND section IS NULL;
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed postcheck failed: % eligible rows have NULL section', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM public.quick_quote_product_mappings
  WHERE status = 'eligible' AND role_key IS NULL;
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed postcheck failed: % eligible rows have NULL role_key', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM public.quick_quote_product_mappings AS mapping
  JOIN public.products AS product ON product.id = mapping.product_id
  WHERE mapping.status = 'eligible'
    AND (product.selling_price IS NULL OR product.selling_price <= 0);
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed postcheck failed: % eligible rows have non-positive current product price', actual_count;
  END IF;

  SELECT count(*) INTO actual_count
  FROM public.quick_quote_product_mappings AS mapping
  LEFT JOIN public.products AS product ON product.id = mapping.product_id
  WHERE product.id IS NULL;
  IF actual_count <> 0 THEN
    RAISE EXCEPTION 'Quick Quote seed postcheck failed: % orphan product references', actual_count;
  END IF;
END;
$quick_quote_seed_postcheck$;

DROP TABLE quick_quote_product_mapping_seed_source;
