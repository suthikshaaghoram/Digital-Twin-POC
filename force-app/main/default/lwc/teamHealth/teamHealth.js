import { LightningElement, wire } from 'lwc';
import getMyTeam from '@salesforce/apex/DashboardController.getMyTeam';

const COLUMNS = [
    {
        label: 'Name',
        fieldName: 'link',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_self'
        }
    },
    {
        label: 'Burnout',
        fieldName: 'Burnout_Score__c',
        type: 'number',
        cellAttributes: {
            class: { fieldName: 'burnoutClass' }
        }
    },
    {
        label: 'Level',
        fieldName: 'Burnout_Level__c'
    },
    {
        label: 'Overtime 30d',
        fieldName: 'Total_Overtime_30d__c',
        type: 'number'
    },
    {
        label: 'Weekend days',
        fieldName: 'Weekend_Days_30d__c',
        type: 'number'
    },
    {
        label: 'Attrition',
        fieldName: 'Attrition_Score__c',
        type: 'number'
    },
    {
        label: 'Promotion',
        fieldName: 'Promotion_Score__c',
        type: 'number'
    }
];

export default class TeamHealth extends LightningElement {

    columns = COLUMNS;
    rows = [];
    error;
    loaded = false;

    @wire(getMyTeam)
    wiredTeam({ data, error }) {

        if (data) {
            this.rows = data.map((r) => ({
                ...r,
                link: '/' + r.Id,

                burnoutClass:
                    r.Burnout_Level__c === 'High' ||
                    r.Burnout_Level__c === 'Critical'
                        ? 'slds-text-color_error'
                        : ''
            }));

            this.error = undefined;
            this.loaded = true;

        } else if (error) {

            this.error =
                error?.body?.message ||
                'Could not load your team.';

            this.loaded = true;
        }
    }

    get hasTeam() {
        return this.rows.length > 0;
    }
}