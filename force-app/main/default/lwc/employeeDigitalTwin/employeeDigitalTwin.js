import { LightningElement, api, wire } from 'lwc';
import getEmployeeTwin from '@salesforce/apex/DigitalTwinController.getEmployeeTwin';

export default class EmployeeDigitalTwin extends LightningElement {

    
    @api recordId;

    twin;
    error;


    @wire(getEmployeeTwin, { employeeId: '$recordId' })
    wiredTwin({ data, error }) {

        if (data) {
            this.twin = data;
            this.error = undefined;
        } else if (error) {
            this.twin = undefined;
            this.error = error?.body?.message || 'Could not load the employee.';
        }
    }

    
    get emp() {
        return this.twin ? this.twin.employee : {};
    }

    
    get hasScores() {
        const e = this.emp;

        return e.Burnout_Score__c !== undefined ||
            e.Last_Score_Date__c !== undefined;
    }

    
    get summaryLine() {
        const e = this.emp;

        return [
            e.Department__r?.Name,
            e.Manager__r?.Name ? 'Manager: ' + e.Manager__r.Name : null,
            e.Employment_Status__c
        ].filter(Boolean).join(' | ');
    }

    
    get reasons() {
        const e = this.emp;

        const list = [
            `Overtime: ${e.Total_Overtime_30d__c ?? 0} h in 30 days (50 h = full points)`,
            `Weekend days worked: ${e.Weekend_Days_30d__c ?? 0} in 30 days (6 = full points)`,
            `Average feedback rating: ${e.Avg_Feedback_Rating__c ?? 'no feedback yet'}`,
            `Approved leave days this year: ${e.Leave_Days_YTD__c ?? 0}`
        ];

        if (e.Last_Score_Date__c) {
            list.push(
                'Last calculated: ' +
                new Date(e.Last_Score_Date__c).toLocaleString()
            );
        }

        return list.map((text, i) => ({
            id: i,
            text
        }));
    }

    
    get hasAttendance() {
        return !!(
            this.twin &&
            this.twin.attendance &&
            this.twin.attendance.length
        );
    }

    
    get bars() {
        return (this.twin?.attendance || []).map((a) => {

            const ot = a.Overtime_Hours__c || 0;
            const height = Math.max(4, Math.min(100, (ot / 4) * 100));

            return {
                key: a.Id,
                title: `${a.Date__c}: ${ot.toFixed(1)} h overtime`,
                cls: a.Is_Weekend__c ? 'bar weekend' : 'bar',
                style: `height: ${height}%;`
            };
        });
    }

    
    get goals() {
        return (this.twin?.goals || []).map((g) => ({

            Id: g.Id,
            title: g.Goal_Title__c,

            pct: g.Target_Value__c
                ? Math.min(
                    100,
                    Math.round(
                        ((g.Actual_Value__c || 0) / g.Target_Value__c) * 100
                    )
                )
                : 0
        }));
    }

    
    get certs() {
        return (this.twin?.certifications || []).map((c) => {

            const flag = c.Status_Flag__c;

            const tone = flag === 'Expired'
                ? 'bad'
                : flag === 'Active'
                    ? 'ok'
                    : 'warn';

            return {
                Id: c.Id,
                name: c.Certification_Name__c,
                flag,
                cls: 'pill ' + tone
            };
        });
    }

    
    get trainings() {
        return (this.twin?.trainings || []).map((t) => ({

            Id: t.Id,
            course: t.Course__r?.Name,
            status: t.Status__c,
            due: t.Due_Date__c || 'n/a'
        }));
    }
}