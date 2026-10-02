{% macro specialty_bucket(col) %}
    case
        when {{ col }} ilike '%pharmac%' then 'Pharmacist / pharmacy'
        when {{ col }} in ('Nurse Practitioner', 'Physician Assistant', 'Certified Nurse Midwife',
                           'Certified Clinical Nurse Specialist', 'Certified Registered Nurse Anesthetist (CRNA)',
                           'Anesthesiologist Assistant') then 'NP / PA'
        when {{ col }} is null then 'Other / unknown'
        when {{ col }} in ('Dentist', 'Optometry', 'Podiatry', 'Chiropractic', 'Clinical Psychologist',
                           'Student in an Organized Health Care Education/Training Program', 'Clinical Social Worker',
                           'Licensed Clinical Social Worker', 'Audiologist', 'Physical Therapist in Private Practice',
                           'Occupational Therapist in Private Practice', 'Registered Dietitian or Nutrition Professional',
                           'Mass Immunizer Roster Biller', 'Centralized Flu', 'Unknown Supplier/Provider Specialty',
                           'Clinic or Group Practice', 'Hospital', 'Public Health or Welfare Agency',
                           'Oral Surgery (Dentist only)', 'Oral Surgery (dentists only)', 'Dental Anesthesiology',
                           'Unknown Physician Specialty Code', 'All Other Suppliers', 'Undefined Physician type',
                           'Opticians', 'Nurse Anesthetist') then 'Other / unknown'
        else 'Physician'
    end
{% endmacro %}

{% macro is_nyc_zip(col) %}
    substr({{ col }}, 1, 3) in ('100', '101', '102', '103', '104', '110', '111', '112', '113', '114', '116')
{% endmacro %}
