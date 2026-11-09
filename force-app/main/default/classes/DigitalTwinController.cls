public with sharing class DigitalTwinController 
{    
    public class TwinData {        
        @AuraEnabled public Employee__c employee;        
        @AuraEnabled public List<Goal__c> goals = new List<Goal__c>();        
        @AuraEnabled public List<Certification__c> certifications = new List<Certification__c>();        
        @AuraEnabled public List<Training__c> trainings = new List<Training__c>();        
        @AuraEnabled public List<Attendance__c> attendance = new List<Attendance__c>();    
    	}    
    	@AuraEnabled(cacheable=true)    
    	public static TwinData getEmployeeTwin(Id employeeId) 
        {        
            List<Employee__c> emps = [SELECT Id, Name, Employee_ID__c, Email__c, Employment_Status__c, Joining_Date__c, Annual_Leave_Balance__c, Department__r.Name, Manager__r.Name, Burnout_Score__c, Burnout_Level__c, Promotion_Score__c, Attrition_Score__c, Attrition_Level__c, Performance_Score__c, Total_Overtime_30d__c, Weekend_Days_30d__c, Last_Score_Date__c, Avg_Feedback_Rating__c, Leave_Days_YTD__c FROM Employee__c WHERE Id = :employeeId LIMIT 1 ];
            if (emps.isEmpty()) {            
                throw new AuraHandledException('Employee not found.');        
            }
            TwinData d = new TwinData();
            d.employee = (Employee__c) clean(emps)[0];
            if (Schema.sObjectType.Goal__c.isAccessible()) 
            { 
                d.goals = (List<Goal__c>) clean([ SELECT Id, Goal_Title__c, Target_Value__c, Actual_Value__c, Deadline__c, Status__c FROM Goal__c WHERE Employee__c = :employeeId ORDER BY Deadline__c DESC LIMIT 6 ]);
			}
            if (Schema.sObjectType.Certification__c.isAccessible()) {            
                d.certifications = (List<Certification__c>) clean([ SELECT Id,Name, Expiry_Date__c, Days_To_Expire__c, Status_Flag__c FROM Certification__c WHERE Employee__c = :employeeId ORDER BY Expiry_Date__c LIMIT 10 ]); 
            }
            if (Schema.sObjectType.Training__c.isAccessible()) {
                d.trainings = (List<Training__c>) clean([ SELECT Id, Course__r.Name, Status__c, Due_Date__c FROM Training__c WHERE Employee__c = :employeeId ORDER BY Due_Date__c DESC LIMIT 6 ]);        
            }
            if (Schema.sObjectType.Attendance__c.isAccessible()) {            
                Date since = Date.today().addDays(-13); 
                d.attendance = (List<Attendance__c>) clean([ SELECT Id, Date__c, Overtime_Hours__c, Is_Weekend__c, Status__c FROM Attendance__c WHERE Employee__c = :employeeId AND Date__c >= :since ORDER BY Date__c ]); 
            }
            return d;
        }
    private static List<SObject> clean(List<SObject> rows) 
    {
        if (rows.isEmpty()) 
        { 
            return rows; 
        }
        return Security.stripInaccessible(AccessType.READABLE, rows).getRecords(); 
    } 
}