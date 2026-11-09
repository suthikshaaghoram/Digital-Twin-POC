import { LightningElement, wire } from 'lwc';

import getEmployeeScores
    from '@salesforce/apex/EmployeeScoreController.getEmployeeScores';

import recalculateScores
    from '@salesforce/apex/EmployeeScoreController.recalculateScores';

import { refreshApex } from '@salesforce/apex';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class EmployeeScoreDashboard extends LightningElement {

    employees = [];
    filteredEmployees = [];

    searchKey = '';
    isLoading = true;

    wiredEmployeeResult;
    lastUpdated = 'Not calculated';

    columns = [
        {
            label: 'Employee',
            fieldName: 'Name',
            type: 'text'
        },
        {
            label: 'Employee ID',
            fieldName: 'Employee_ID__c',
            type: 'text'
        },
        {
            label: 'Department',
            fieldName: 'departmentName',
            type: 'text'
        },
        {
            label: 'Burnout Score',
            fieldName: 'Burnout_Score__c',
            type: 'number'
        },
        {
            label: 'Burnout Level',
            fieldName: 'Burnout_Level__c',
            type: 'text'
        },
        {
            label: 'Promotion Score',
            fieldName: 'Promotion_Score__c',
            type: 'number'
        },
        {
            label: 'Attrition Score',
            fieldName: 'Attrition_Score__c',
            type: 'number'
        },
        {
            label: 'Attrition Level',
            fieldName: 'Attrition_Level__c',
            type: 'text'
        },
        {
            label: 'Performance',
            fieldName: 'Performance_Score__c',
            type: 'number'
        },
        {
            label: 'Overtime (30d)',
            fieldName: 'Total_Overtime_30d__c',
            type: 'number'
        },
        {
            label: 'Weekend Days',
            fieldName: 'Weekend_Days_30d__c',
            type: 'number'
        }
    ];

    @wire(getEmployeeScores)
    wiredEmployees(result) {

        this.wiredEmployeeResult = result;

        const { data, error } = result;

        if (data) {

            this.employees = data.map(employee => ({
                ...employee,
                departmentName:
                    employee.Department__r
                        ? employee.Department__r.Name
                        : 'Not Assigned'
            }));

            this.applySearch();

            this.lastUpdated = new Date().toLocaleString();

            this.isLoading = false;

        } else if (error) {

            this.isLoading = false;

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        }
    }

    get totalEmployees() {
        return this.employees.length;
    }

    get highBurnoutCount() {
        return this.employees.filter(employee =>
            employee.Burnout_Score__c >= 70
        ).length;
    }

    get promotionCount() {
        return this.employees.filter(employee =>
            employee.Promotion_Score__c >= 90
        ).length;
    }

    get highAttritionCount() {
        return this.employees.filter(employee =>
            employee.Attrition_Score__c >= 70
        ).length;
    }

    get hasRecords() {
        return this.filteredEmployees.length > 0;
    }

    handleSearch(event) {

        this.searchKey = event.target.value.toLowerCase();

        this.applySearch();
    }

    applySearch() {

        if (!this.searchKey) {
            this.filteredEmployees = [...this.employees];
            return;
        }

        this.filteredEmployees = this.employees.filter(employee =>
            employee.Name?.toLowerCase().includes(this.searchKey) ||
            employee.Employee_ID__c?.toLowerCase().includes(this.searchKey)
        );
    }

    async handleRecalculate() {

        this.isLoading = true;

        try {

            const employeeIds = this.employees.map(
                employee => employee.Id
            );

            await recalculateScores({
                employeeIds: employeeIds
            });

            await refreshApex(this.wiredEmployeeResult);

            this.showToast(
                'Success',
                'Employee scores recalculated successfully.',
                'success'
            );

        } catch (error) {

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );

        } finally {

            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    getErrorMessage(error) {

        return error?.body?.message ||
            'An unexpected error occurred.';
    }
}