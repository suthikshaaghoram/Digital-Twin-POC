import { LightningElement, wire } from 'lwc';

import getMyEmployee
    from '@salesforce/apex/EmployeeSelfServiceController.getMyEmployee';

import updateMyEmployee
    from '@salesforce/apex/EmployeeSelfServiceController.updateMyEmployee';

import { refreshApex } from '@salesforce/apex';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class EmployeeSelfServiceDashboard extends LightningElement {

    employee;
    isLoading = true;
    isEditing = false;
    isSaving = false;

    editEmail = '';
    editPhone = '';

    wiredEmployeeResult;

    acceptedFormats = [
        '.pdf',
        '.png',
        '.jpg',
        '.jpeg',
        '.doc',
        '.docx'
    ];

    @wire(getMyEmployee)
    wiredEmployee(result) {

        this.wiredEmployeeResult = result;

        if (result.data) {

            this.employee = result.data;

            this.isLoading = false;

        } else if (result.error) {

            this.employee = undefined;

            this.isLoading = false;

            this.showToast(
                'Error',
                this.getErrorMessage(result.error),
                'error'
            );
        }
    }

    handleEdit() {

        this.editEmail = this.employee.Email__c || '';

        this.editPhone = this.employee.Phone__c || '';

        this.isEditing = true;
    }

    handleCancel() {

        this.isEditing = false;

        this.editEmail = '';

        this.editPhone = '';
    }

    handleEmailChange(event) {

        this.editEmail = event.target.value;
    }

    handlePhoneChange(event) {

        this.editPhone = event.target.value;
    }

    async handleSave() {

        const inputs = [
            ...this.template.querySelectorAll('lightning-input')
        ];

        const allValid = inputs.reduce((valid, input) => {
            input.reportValidity();
            return valid && input.checkValidity();
        }, true);

        if (!allValid) {
            return;
        }

        this.isSaving = true;

        try {

            await updateMyEmployee({
                email: this.editEmail,
                phone: this.editPhone
            });

            await refreshApex(this.wiredEmployeeResult);

            this.isEditing = false;

            this.showToast(
                'Success',
                'Your employee profile has been updated successfully.',
                'success'
            );

        } catch (error) {

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );

        } finally {

            this.isSaving = false;
        }
    }

    handleUploadFinished(event) {

        const uploadedFiles = event.detail.files;

        this.showToast(
            'Upload Successful',
            uploadedFiles.length + ' document(s) uploaded successfully.',
            'success'
        );
    }

    getErrorMessage(error) {

        if (error?.body?.message) {
            return error.body.message;
        }

        return 'An unexpected error occurred.';
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
}