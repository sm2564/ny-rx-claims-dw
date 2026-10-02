-- The three payer segments of the NY All-Payer Database prescription PUFs, with the program
-- definitions that matter for the policy study.

select *
from (
    values
    ('COMMERCIAL', 'Commercial',
     'Insurer-submitted pharmacy claims for fully insured and self-funded (ERISA) employer plans, individual and small-group market plans, and employer retiree plans that are not Part D. All ages. The 65+ slice is contaminated by switching into Medicare (65+ fills fell 22% in 2023 vs 13% for 45-64).',
     false, 'Control segment, restricted to ages 45-64'),
    ('MEDICARE', 'Medicare',
     'Medicare drug plans covering New York residents: stand-alone Part D (PDP) and Medicare Advantage drug plans (MA-PD). Part B drugs and vaccines (influenza, pneumococcal, COVID-19) are medical claims and are not here.',
     true, 'Treated segment: IRA $0 cost sharing for Part D vaccines from 2023-01-01'),
    ('NYS PROGRAMS', 'NYS Programs (Medicaid and state plans)',
     'Medicaid fee-for-service and managed care, Child Health Plus, and the Essential Plan. The 2023-04-01 NYRx carve-out moved managed-care pharmacy benefits to fee-for-service and vaccine rows fall about 75% in 2023.',
     false, 'Documented break 2023-04-01 (NYRx); not a usable 2023 control')
) as t (payer_type, payer_name, payer_definition, is_ira_treated, study_role)
