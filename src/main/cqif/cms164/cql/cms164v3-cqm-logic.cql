library cms164v3-cqm-logic version '1'

include Common version '1' called Common  

using QDM

valueset "Diagnosis, Active: Acute Myocardial Infarction":'2.16.840.1.113883.3.464.1003.104.12.1001'
valueset "Diagnosis, Active: Ischemic Vascular Disease":'2.16.840.1.113883.3.464.1003.104.12.1003'
valueset "Medication, Active: Aspirin and Other Anti-thrombotics":'2.16.840.1.113883.3.464.1003.196.12.1211'
valueset "Procedure, Performed: Coronary Artery Bypass Graft":'2.16.840.1.113883.3.464.1003.104.12.1002'
valueset "Procedure, Performed: Percutaneous Coronary Interventions":'2.16.840.1.113883.3.464.1003.104.12.1010'


/*******************************************************************************
 *  Define relevant evaluation periods
 *******************************************************************************/

/**
 * Assuming measurement period is the full current calendar year
 */
define MeasurementPeriod: 
    interval [Date( year of today(), 1, 1 ), Date(year of today(), 12, 31 )]

/** 
 * Patients who were discharged alive for acute myocardial infarction (AMI), coronary artery bypass graft (CABG) 
 * or percutaneous coronary interventions (PCI) in the 12 months 'prior' to the measurement period"
 */
define ACSReviewWindow:
    interval [Date( ((year of today()) - 1 years), 1, 1 ), Date( ((year of today()) - 1 years), 12, 31 )]

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
    ["Diagnosis": "Diagnosis, Active: Ischemic Vascular Disease"] IVD where IVD."abatement date" is not null

define hasIVD:
  exists IVD

/*******************************************************************************
 *  Some setup
 *******************************************************************************/

define DischargedDuringACSReviewWindow:
  ["Encounter, Performed": "Inpatient"] E   //TODO Need a value set
    where E."stop datetime" during ACSReviewWindow
      and InDemographic

/*******************************************************************************
 *  Identify encounters where encounter condition was AMI or where PCI or CABG was performed
 *******************************************************************************/

/**
 * Handling AMI
 */

define AMIDischargeIn12MoPriorToMeasurementPeriod:
  DischargedDuringACSReviewWindow E
    where E."Principal Diagnosis" = "Diagnosis Active: Acute Myocardial Infarction" 
    or E."Diagnosis" = "Diagnosis Active: Acute Myocardial Infarction"


define hasAMI:
  exists AMIDischargeIn12MoPriorToMeasurementPeriod

/**
 * Handling IHD
 */

//Option 1
define IHDDischargeIn12MoPriorToMeasurementPeriod: //Is procedure really a data type of Encounter?
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
    	with IHDProcedure P such that Interval[P."start datetime", P."stop datetime"] during Interval[E."start datetime", E."stop datetime"]

define hasIHD:
	exists IHDDischargeIn12MoPriorToMeasurementPeriod

/*******************************************************************************
 * Handle implicit exclusion: Identify encounter(s) where the patient died
 *******************************************************************************/
define EncountersInWhichPatientExpired:
  DischargedDuringACSReviewWindow E
    with ["Patient Characteristic, Expired"] D such that D.Date = E."Discharge Datetime"

define excluded:
  exists(EncountersInWhichPatientExpired)

/*******************************************************************************
 * Handle numerator criteria
 *******************************************************************************/
define OnAntiThrombotics://Should we include more: e.g., orders, administrations, etc...?
  ["Medication, Active": "Medication, Active: Aspirin and Other Anti-thrombotics"] M   //Need a value set that includes aspirin
    where Interval[M."start datetime", M."stop datetime"] overlaps before MeasurementPeriod
    and M."stop datetime" is not null

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
