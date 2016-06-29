library "cms164v3-cqm-logic" version '1' // NOTE: Dashes are not valid in an identifier, so you have to quote it to do this

include Common version '1' called Common  

using QDM version '5.0' // NOTE: Should specify the version of QDM, 5.0 in this case

// NOTE: We have typically not included the QDM category and data type name in the local value set name
valueset "Diagnosis, Active: Acute Myocardial Infarction":'urn:oid:2.16.840.1.113883.3.464.1003.104.12.1001' // NOTE: Terminology references should be urns
valueset "Diagnosis, Active: Ischemic Vascular Disease":'urn:oid:2.16.840.1.113883.3.464.1003.104.12.1003'
valueset "Medication, Active: Aspirin and Other Anti-thrombotics":'urn:oid:2.16.840.1.113883.3.464.1003.196.12.1211'
valueset "Procedure, Performed: Coronary Artery Bypass Graft":'urn:oid:2.16.840.1.113883.3.464.1003.104.12.1002'
valueset "Procedure, Performed: Percutaneous Coronary Interventions":'urn:oid:2.16.840.1.113883.3.464.1003.104.12.1010'


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
define InDemographic: 
        AgeInYearsAt(start of MeasurementPeriod) >= 18

/*******************************************************************************
 *  Define IVD
 *******************************************************************************/

define IVD: 
    ["Diagnosis": "Diagnosis, Active: Ischemic Vascular Disease"] IVD where IVD.abatementDate is not null

define hasIVD:
  exists IVD

/*******************************************************************************
 *  Some setup
 *******************************************************************************/

define DischargedDuringACSReviewWindow:
  ["Encounter, Performed": "Inpatient"] E   //TODO Need a value set
    where E.relevantPeriod ends during ACSReviewWindow
      and InDemographic

/*******************************************************************************
 *  Identify encounters where encounter condition was AMI or where PCI or CABG was performed
 *******************************************************************************/

/**
 * Handling AMI
 */

define AMIDischargeIn12MoPriorToMeasurementPeriod:
  distinct
    DischargedDuringACSReviewWindow E
      where E.diagnosis in "Diagnosis Active: Acute Myocardial Infarction" // NOTE: I have only ever seen this referenced as diagnosis, even though the QDM spec says principalDiagnosis, not sure which is correct
    union
      DischargedDuringACSReviewWindow E
      	with ["Diagnosis": "Diagnosis Active: Acute Myocardial Infarction"] D
      	  such that D.relevantPeriod starts during E.relevantPeriod

define hasAMI:
  exists AMIDischargeIn12MoPriorToMeasurementPeriod

/**
 * Handling IHD
 */

//Option 1
define IHDDischargeIn12MoPriorToMeasurementPeriod: //Is procedure really a data type of Encounter? // NOTE: No, it is not
  DischargedDuringACSReviewWindow E where 
    (E."Procedure" = "Procedure, Performed: Percutaneous Coronary Interventions"
      or
     E."Procedure" = "Procedure, Performed: Coronary Artery Bypass Graft")

//Option 2
define IHDprocedure:
        ( [Procedure, Performed: "Procedure, Performed: Percutaneous Coronary Interventions"]
            union 
          [Procedure, Performed: "Procedure, Performed: Coronary Artery Bypass Graft"] )
                
define IHDDischargeIn12MoPriorToMeasurementPeriod:
    DischargedDuringACSReviewWindow E
    	with IHDProcedure P such that P.relevantPeriod during E.relevantPeriod

define hasIHD:
	exists IHDDischargeIn12MoPriorToMeasurementPeriod

/*******************************************************************************
 * Handle implicit exclusion: Identify encounter(s) where the patient died
 *******************************************************************************/
define EncountersInWhichPatientExpired:
  DischargedDuringACSReviewWindow E
    with ["Patient Characteristic, Expired"] D such that D.expiredDate same day as end of E.relevantPeriod

define excluded:
  exists(EncountersInWhichPatientExpired)

/*******************************************************************************
 * Handle numerator criteria
 *******************************************************************************/
define OnAntiThrombotics://Should we include more: e.g., orders, administrations, etc...?
  ["Medication, Active": "Medication, Active: Aspirin and Other Anti-thrombotics"] M   //Need a value set that includes aspirin
    where M.relevantPeriod overlaps before MeasurementPeriod
    and end of M.relevantPeriod is not null

//Check orders? Check dispense? Ask Anne. Talk to Bryn about a function to calculate prescribed med - cummulative medication duration > threshold.

/*******************************************************************************
 * Handle numerator criteria
 *******************************************************************************/

define InitialPopulation:
	InDemographic and (HasIVD OR HasAMI OR HasIHD) and not excluded

define denominator:
  InitialPopulation

define numerator:
	InitialPopulation and OnAntiThrombotics
