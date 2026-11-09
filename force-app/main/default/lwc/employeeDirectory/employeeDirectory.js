import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

import getEmployees from
    '@salesforce/apex/CEOEmployeeDirectoryController.getEmployees';

import getDepartments from
    '@salesforce/apex/CEOEmployeeDirectoryController.getDepartments';

const ROW_ACTIONS = [
    { label: 'View Profile', name: 'view_profile' }
];

const COLUMNS = [
    { label: 'Employee ID', fieldName: 'Employee_ID__c' },
    { label: 'Employee Name', fieldName: 'Name' },
    { label: 'Email', fieldName: 'Email__c', type: 'email' },
    { label: 'Department', fieldName: 'departmentName' },
    { label: 'Job Role', fieldName: 'jobRoleName' },
    { label: 'Manager', fieldName: 'managerName' },
    { label: 'Joining Date', fieldName: 'Joining_Date__c', type: 'date' },
    { label: 'Status', fieldName: 'Employment_Status__c' },
    {
        type: 'action',
        typeAttributes: { rowActions: ROW_ACTIONS }
    }
];

export default class EmployeeDirectory extends NavigationMixin(
    LightningElement
) {
    columns = COLUMNS;

    employees = [];
    totalRecords = 0;
    pageNumber = 1;
    pageSize = 25;

    searchKey = '';
    selectedDepartment = '';
    selectedStatus = '';

    isLoading = true;
    wiredEmployeeResult;

    departmentOptions = [
        { label: 'All Departments', value: '' }
    ];

    statusOptions = [
        { label: 'All Statuses', value: '' },
        { label: 'Active', value: 'Active' },
        { label: 'On Leave', value: 'On Leave' },
        { label: 'Notice Period', value: 'Notice Period' },
        { label: 'Exited', value: 'Exited' }
    ];

    @wire(getDepartments)
    wiredDepartments({ data, error }) {
        if (data) {
            this.departmentOptions = [
                { label: 'All Departments', value: '' },
                ...data.map(item => ({
                    label: item.label,
                    value: item.value
                }))
            ];
        } else if (error) {
            this.departmentOptions = [
                { label: 'All Departments', value: '' }
            ];
        }
    }

    @wire(getEmployees, {
        searchKey: '$searchKey',
        departmentId: '$selectedDepartment',
        employmentStatus: '$selectedStatus',
        pageNumber: '$pageNumber',
        pageSize: '$pageSize'
    })
    wiredEmployees(result) {
        this.wiredEmployeeResult = result;
        this.isLoading = false;

        if (result.data) {
            this.totalRecords = result.data.totalRecords;

            this.employees = result.data.employees.map(employee => ({
                ...employee,
                departmentName: employee.Department__r?.Name,
                jobRoleName: employee.Job_Role__r?.Name,
                managerName: employee.Manager__r?.Name
            }));
        } else if (result.error) {
            this.employees = [];
            this.totalRecords = 0;
            this.errorMessage = result.error.body?.message || result.error.message || 'Unable to load employee records.';
        }
    }

    handleSearch(event) {
        this.searchKey = event.target.value;
        this.pageNumber = 1;
    }

    handleDepartmentChange(event) {
        this.selectedDepartment = event.detail.value;
        this.pageNumber = 1;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.pageNumber = 1;
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
        }
    }

    handleNext() {
        if (!this.isLastPage) {
            this.pageNumber++;
        }
    }

    handleRefresh() {
        this.isLoading = true;
        return refreshApex(this.wiredEmployeeResult);
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const employee = event.detail.row;

        if (actionName === 'view_profile') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: employee.Id,
                    objectApiName: 'Employee__c',
                    actionName: 'view'
                }
            });
        }
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
    }

    get isFirstPage() {
        return this.pageNumber <= 1;
    }

    get isLastPage() {
        return this.pageNumber >= this.totalPages;
    }

    get hasRecords() {
        return this.employees.length > 0;
    }

    get noRecords() {
        return !this.isLoading && this.employees.length === 0;
    }

    get pageLabel() {
        return `Page ${this.pageNumber} of ${this.totalPages}`;
    }
}