library "cms164v3-cqm-logic" version '1' // NOTE: Dashes are not valid in an identifier, so you have to quote it to do this

include Common version '1' called Common  

using QDM version '5.0' // NOTE: Should specify the version of QDM, 5.0 in this case

valueset "Acute Myocardial Infarction":'urn:oid:2.16.840.1.113883.3.464.1003.104.12.1001' // NOTE: Terminology references should be urns
valueset "Ischemic Vascular Disease":'urn:oid:2.16.840.1.113883.3.464.1003.104.12.1003'
valueset "Aspirin and Other Anti-thrombotics":'urn:oid:2.16.840.1.113883.3.464.1003.196.12.1211'
valueset "Coronary Artery Bypass Graft":'urn:oid:2.16.840.1.113883.3.464.1003.104.12.1002'
valueset "Percutaneous Coronary Interventions":'urn:oid:2.16.840.1.113883.3.464.1003.104.12.1010'


/*******************************************************************************
 *  Define relevant evaluation periods
 *******************************************************************************/

/**
 * Assuming measurement period is the full current calendar year
 */
// NOTE: Should use parameter rather than define here so it can be provided as part of the evaluation request
parameter MeasurementPeriod: 
    Interval [Date( year of Today(), 1, 1 ), Date(year of Today(), 12, 31 )] // NOTE: Changes in casing, Interval is a type name, must be Pascal-cased, Today is a function name, must be Pascal-cased

/** 
 * Patients who were discharged alive for acute myocardial infarction (AMI), coronary artery bypass graft (CABG) 
 * or percutaneous coronary interventions (PCI) in the 12 months 'prior' to the measurement period"
 */
define ACSReviewWindow:
    Interval [Date( ((year of Today()) - 1 years), 1, 1 ), Date( ((year of Today()) - 1 years), 12, 31 )]

/*******************************************************************************
 *  Define demographic
 *******************************************************************************/

/* 
 *  initial patient population criteria -- age >= 18 yrs
 */
define "In Demographic": 
        AgeInYearsAt(start of MeasurementPeriod) >= 18

/*******************************************************************************
 *  Define IVD
 *******************************************************************************/

define IVD: 
    ["Diagnosis": "Ischemic Vascular Disease"] IVD where IVD.abatementDate is not null

define "Has IVD":
  exists IVD

/*******************************************************************************
 *  Some setup
 *******************************************************************************/

define "Discharged During ACS Review Window":
  ["Encounter, Performed": "Inpatient"] E   //TODO Need a value set
    where E.relevantPeriod ends during ACSReviewWindow
      and InDemographic

/*******************************************************************************
 *  Identify encounters where encounter condition was AMI or where PCI or CABG was performed
 *******************************************************************************/

/**
 * Handling AMI
 */

define "AMI Discharge In 12 Month Prior To Measurement Period":
  distinct
    "Discharged During ACS Review Window" E
      where E.diagnosis in "Acute Myocardial Infarction" // NOTE: I have only ever seen this referenced as diagnosis, even though the QDM spec says principalDiagnosis, not sure which is correct
    union
      "Discharged During ACS Review Window" E
      	with ["Diagnosis": "Acute Myocardial Infarction"] D
      	  such that D.relevantPeriod starts during E.relevantPeriod

define "Has AMI":
  exists "AMI Discharge In 12 Month Prior To Measurement Period"

/**
 * Handling IHD
 */

define IHDprocedure:
        ( [Procedure, Performed: "Percutaneous Coronary Interventions"]
            union 
          [Procedure, Performed: "Coronary Artery Bypass Graft"] )
                
define "IHD Discharge In 12 Month Prior To Measurement Period":
    "Discharged During ACS Review Window" E
    	with IHDProcedure P such that P.relevantPeriod during E.relevantPeriod

define "Has IHD":
	exists "IHD Discharge In 12 Month Prior To Measurement Period"

/*******************************************************************************
 * Handle implicit exclusion: Identify encounter(s) where the patient died
 *******************************************************************************/
define "Encounters In Which Patient Expired":
  "Discharged During ACS Review Window" E
    with ["Patient Characteristic, Expired"] D such that D.expiredDate same day as end of E.relevantPeriod

define Excluded:
  exists "Encounters In Which Patient Expired"

/*******************************************************************************
 * Handle numerator criteria
 *******************************************************************************/
define "On AntiThrombotics"://Should we include more: e.g., orders, administrations, etc...?
  ["Medication, Active": "Aspirin and Other Anti-thrombotics"] M   //Need a value set that includes aspirin
    where M.relevantPeriod overlaps before MeasurementPeriod
    and end of M.relevantPeriod is not null

/*******************************************************************************
 * Handle numerator criteria
 *******************************************************************************/

define "Initial Population":
	InDemographic and ("Has IVD" OR "Has AMI" OR "Has IHD") and not Excluded

define Denominator:
  "Initial Population"

define Numerator:
	"Initial Population" and "On AntiThrombotics"
