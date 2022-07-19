CREATE TABLE pathology_encounters
(
	order_id					INT, 
	order_number					VARCHAR(50), 
	encounter_id					INT, 
	patient_id					INT,	
	emr_id						VARCHAR(50), 
	loc_registered					VARCHAR(255), 
	patient_name					VARCHAR(255), 
	unknown_patient					VARCHAR(50), 
	gender 						VARCHAR(50), 
	age_at_enc					INT, 
	department					VARCHAR(255),
	commune						VARCHAR(255), 
	section						VARCHAR(255), 	
	locality					VARCHAR(255), 
	street_landmark					VARCHAR(255), 
	order_datetime 					DATETIME,
	ordering_provider				VARCHAR(255), 
	request_coded_proc1				VARCHAR(255), 
	request_coded_proc2				VARCHAR(255), 
	request_coded_proc3				VARCHAR(255), 
	request_non_coded_proc				TEXT, 
	prepath_dx					VARCHAR(255), 
	clinical_history				TEXT,
	specimen_accession_number			TEXT, 
	post_op_diagnosis				VARCHAR(255), 
	specimen_details_1				TEXT, 
	specimen_details_2				TEXT,	 
	specimen_details_3				TEXT, 
	specimen_details_4				TEXT, 
	specimen_details_5				TEXT, 
	specimen_details_6				TEXT, 
	specimen_details_7				TEXT, 
	specimen_details_8				TEXT, 
	attending_surgeon				VARCHAR(255), 
	resident					VARCHAR(255), 
	md_to_notify					TEXT, 
	clinician_telephone				TEXT, 
	urgent_review					VARCHAR(255), 
	suspected_cancer				VARCHAR(255),	 
	immunohistochemistry_needed			VARCHAR(255),	 
	immunohistochemistry_sent			VARCHAR(255), 
	date_sent					DATETIME, 
	results_date					DATETIME, 
	results_note					TEXT,
	file_uploaded					VARCHAR(255)
);