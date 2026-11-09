import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDashboard from '@salesforce/apex/DashboardController.getDashboard';
const LEVEL_COLORS = {
    Low: '#16a34a',
    Medium: '#f59e0b',
    High: '#f97316',
    Critical: '#dc2626'
};

const flatten = (r) => ({
    ...r,
    link: '/' + r.Id,
    dept: r.Department__r?.Name
});

const nameColumn = {
    label: 'Name',
    fieldName: 'link',
    type: 'url',
    typeAttributes: {
        label: { fieldName: 'Name' },
        target: '_self'
    }
};

export default class CeoDashboard extends LightningElement {

    data;
    error;
    wiredResult;

    riskColumns = [
        nameColumn,
        { label: 'Department', fieldName: 'dept' },
        {
            label: 'Burnout',
            fieldName: 'Burnout_Score__c',
            type: 'number'
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
        }
    ];

    promoColumns = [
        nameColumn,
        { label: 'Department', fieldName: 'dept' },
        {
            label: 'Promotion',
            fieldName: 'Promotion_Score__c',
            type: 'number'
        },
        {
            label: 'Performance',
            fieldName: 'Performance_Score__c',
            type: 'number'
        }
    ];

    @wire(getDashboard)
    wiredDashboard(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.data = data;
            this.error = undefined;
        } else if (error) {
            this.data = undefined;
            this.error = error?.body?.message || 'Could not load the dashboard.';
        }
    }

    handleRefresh() {
        return refreshApex(this.wiredResult);
    }
    get total() {
        return this.data.totalActive || 1;
    }

    levelItems(counts, order) {
        return order.map((l) => ({
            label: l,
            value: counts[l] || 0,
            color: LEVEL_COLORS[l]
        }));

    }
    get burnoutItems() {
        return this.levelItems(
            this.data.burnoutLevels,
            ['Low', 'Medium', 'High', 'Critical']
        );

    }
    get attritionItems() {
        return this.levelItems(
            this.data.attritionLevels,
            ['Low', 'Medium', 'High']
        );
    }
    get deptItems() {
        return this.data.departments.map((d) => ({
            label: d.department,
            value: d.avgBurnout,
            color: '#6366f1'
        }));

    }

    get burnoutRows() {
        return this.data.topBurnout.map(flatten);
    }
    get promoRows() {
        return this.data.topPromotion.map(flatten);
    }

}