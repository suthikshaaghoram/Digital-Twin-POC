import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getHrDashboard from '@salesforce/apex/HrDashboardController.getHrDashboard';
import getDepartments from '@salesforce/apex/HrDashboardController.getDepartments';
import completeTask from '@salesforce/apex/HrDashboardController.completeTask';
import runScoreRefresh from '@salesforce/apex/HrDashboardController.runScoreRefresh';
import getJobStatus from '@salesforce/apex/HrDashboardController.getJobStatus';
 
const ALL = 'ALL';
const POLL_MS = 3000;
const JOB_DONE = ['Completed', 'Failed', 'Aborted'];
 
const LEVEL_COLORS = {
    Low: '#16a34a',
    Medium: '#f59e0b',
    High: '#f97316',
    Critical: '#dc2626'
};
 
const link = (id) => '/' + id;
 
const employeeLink = {
    label: 'Employee',
    fieldName: 'link',
    type: 'url',
    typeAttributes: { label: { fieldName: 'name' }, target: '_self' }
};
 
const WATCH_COLUMNS = [
    { ...employeeLink, initialWidth: 170 },
    { label: 'Department', fieldName: 'department', initialWidth: 120 },
    { label: 'Manager', fieldName: 'manager', initialWidth: 120 },
    {
        label: 'Burnout', fieldName: 'burnout', type: 'number', initialWidth: 90,
        typeAttributes: { maximumFractionDigits: 0 },
        cellAttributes: { class: { fieldName: 'burnoutClass' } }
    },
    {
        label: 'Attrition', fieldName: 'attrition', type: 'number', initialWidth: 90,
        typeAttributes: { maximumFractionDigits: 0 },
        cellAttributes: { class: { fieldName: 'attritionClass' } }
    },
    {
        label: 'Promotion', fieldName: 'promotion', type: 'number', initialWidth: 95,
        typeAttributes: { maximumFractionDigits: 0 },
        cellAttributes: { class: { fieldName: 'promotionClass' } }
    },
    { label: 'Overtime 30d', fieldName: 'overtime', type: 'number', initialWidth: 110,
        typeAttributes: { maximumFractionDigits: 1 } },
    { label: 'Weekend days', fieldName: 'weekendDays', type: 'number', initialWidth: 110 },
    { label: 'Flags', fieldName: 'flags' },
    { label: 'Suggested action', fieldName: 'suggestedAction' }
];
 
const TASK_COLUMNS = [
    { label: 'Task', fieldName: 'subject' },
    {
        label: 'Employee', fieldName: 'link', type: 'url',
        typeAttributes: { label: { fieldName: 'relatedName' }, target: '_self' }
    },
    { label: 'Priority', fieldName: 'priority', initialWidth: 90 },
    {
        label: 'Due', fieldName: 'dueDate', type: 'date-local', initialWidth: 110,
        cellAttributes: { class: { fieldName: 'dueClass' } }
    },
    { label: 'Owner', fieldName: 'owner', initialWidth: 130 },
    {
        type: 'button', initialWidth: 110,
        typeAttributes: { label: 'Complete', name: 'complete', variant: 'neutral' }
    }
];
 
const ITEM_COLUMNS = [
    {
        label: 'Employee', fieldName: 'link', type: 'url',
        typeAttributes: { label: { fieldName: 'employeeName' }, target: '_self' }
    },
    { label: 'Item', fieldName: 'title' },
    { label: 'Detail', fieldName: 'detail' },
    { label: 'Date', fieldName: 'dueDate', type: 'date-local', initialWidth: 110 },
    { label: 'Status', fieldName: 'status', initialWidth: 160 }
];
 
export default class HrDashboard extends LightningElement {
 
    data;
    error;
    wiredResult;
    departmentId = null;
 
    selectedDept = ALL;
    deptOptions = [{ label: 'All departments', value: ALL }];
    category = 'all';
    searchTerm = '';
    isRecalculating = false;
    jobText = '';
    pollTimer;
 
    watchColumns = WATCH_COLUMNS;
    taskColumns = TASK_COLUMNS;
    itemColumns = ITEM_COLUMNS;
 
    categoryOptions = [
        { label: 'All', value: 'all' },
        { label: 'Burnout', value: 'burnout' },
        { label: 'Attrition', value: 'attrition' },
        { label: 'Promotion', value: 'promotion' }
    ];
 
    @wire(getDepartments)
    wiredDepartments({ data }) {
        if (data) {
            this.deptOptions = [
                { label: 'All departments', value: ALL },
                ...data.map((d) => ({ label: d.label, value: d.value }))
            ];
        }
    }
 
    @wire(getHrDashboard, { departmentId: '$departmentId' })
    wiredDashboard(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.data = data;
            this.error = undefined;
        } else if (error) {
            this.data = undefined;
            this.error = error?.body?.message || 'Could not load the HR dashboard.';
        }
    }
 
    disconnectedCallback() {
        this.stopPolling();
    }
 
    handleDeptChange(event) {
        this.selectedDept = event.detail.value;
        this.departmentId = this.selectedDept === ALL ? null : this.selectedDept;
    }
 
    handleCategoryChange(event) {
        this.category = event.detail.value;
    }
 
    handleSearch(event) {
        this.searchTerm = (event.target.value || '').toLowerCase();
    }
 
    handleRefresh() {
        return refreshApex(this.wiredResult);
    }
 
    async handleTaskAction(event) {
        if (event.detail.action.name !== 'complete') { return; }
        try {
            await completeTask({ taskId: event.detail.row.id });
            this.toast('Task completed', event.detail.row.subject, 'success');
            await refreshApex(this.wiredResult);
        } catch (e) {
            this.toast('Could not complete task', e?.body?.message || e.message, 'error');
        }
    }
 
    async handleRecalculate() {
        try {
            this.isRecalculating = true;
            this.jobText = 'Starting...';
            const jobId = await runScoreRefresh();
            this.pollTimer = setInterval(() => this.checkJob(jobId), POLL_MS);
        } catch (e) {
            this.isRecalculating = false;
            this.toast('Could not start recalculation', e?.body?.message || e.message, 'error');
        }
    }
 
    async checkJob(jobId) {
        try {
            const job = await getJobStatus({ jobId });
            this.jobText = job.total ? `${job.processed}/${job.total}` : job.status;
            if (JOB_DONE.includes(job.status)) {
                this.stopPolling();
                this.isRecalculating = false;
                await refreshApex(this.wiredResult);
                if (job.status === 'Completed') {
                    this.toast('Scores recalculated', 'The dashboard now shows the latest scores.', 'success');
                } else {
                    this.toast('Recalculation ' + job.status.toLowerCase(), 'Check Setup > Apex Jobs.', 'warning');
                }
            }
        } catch (e) {
            this.stopPolling();
            this.isRecalculating = false;
            this.toast('Could not read job status', e?.body?.message || e.message, 'error');
        }
    }
 
    stopPolling() {
        if (this.pollTimer) {
            clearInterval(this.pollTimer);
            this.pollTimer = undefined;
        }
    }
 
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
 
    get isLoading() {
        return !this.data && !this.error;
    }
 
    get canRefreshScores() {
        return !!(this.data && this.data.canRefreshScores);
    }
 
    get recalcLabel() {
        return this.isRecalculating ? `Recalculating ${this.jobText}` : 'Recalculate scores';
    }
 
    get total() {
        return (this.data && this.data.totalActive) || 1;
    }
 
    get lastScoreText() {
        return this.data && this.data.lastScoreDate
            ? new Date(this.data.lastScoreDate).toLocaleString()
            : 'not yet';
    }
 
    get overdueTaskSub() {
        const n = this.data ? this.data.overdueTaskCount : 0;
        return n ? `${n} overdue` : 'none overdue';
    }
 
    get taskTone() {
        return this.data && this.data.overdueTaskCount ? 'danger' : 'info';
    }
 
    get watchRows() {
        const rows = (this.data && this.data.watchlist) || [];
        return rows
            .filter((r) => {
                if (this.category === 'burnout' && !r.isBurnout) { return false; }
                if (this.category === 'attrition' && !r.isAttrition) { return false; }
                if (this.category === 'promotion' && !r.isPromotion) { return false; }
                return !this.searchTerm || (r.name || '').toLowerCase().includes(this.searchTerm);
            })
            .map((r) => ({
                ...r,
                link: link(r.id),
                burnoutClass: r.isBurnout ? 'slds-text-color_error' : '',
                attritionClass: r.isAttrition ? 'slds-text-color_error' : '',
                promotionClass: r.isPromotion ? 'slds-text-color_success' : ''
            }));
    }
 
    get hasWatchRows() {
        return this.watchRows.length > 0;
    }
 
    get taskRows() {
        return ((this.data && this.data.tasks) || []).map((t) => ({
            ...t,
            link: link(t.relatedId),
            dueClass: t.overdue ? 'slds-text-color_error' : ''
        }));
    }
 
    get certRows() {
        return this.itemRows(this.data && this.data.certs);
    }
 
    get trainingRows() {
        return this.itemRows(this.data && this.data.trainings);
    }
 
    get leaveRows() {
        return this.itemRows(this.data && this.data.leaves);
    }
 
    itemRows(list) {
        return (list || []).map((i) => ({ ...i, link: link(i.employeeId) }));
    }
 
    get hasTasks() { return this.taskRows.length > 0; }
    get hasCerts() { return this.certRows.length > 0; }
    get hasTrainings() { return this.trainingRows.length > 0; }
    get hasLeaves() { return this.leaveRows.length > 0; }
 
    get taskTabLabel() { return `HR tasks (${this.data ? this.data.openTaskCount : 0})`; }
    get certTabLabel() { return `Certifications (${this.data ? this.data.certExpiringCount : 0})`; }
    get trainingTabLabel() { return `Training (${this.data ? this.data.trainingOverdueCount : 0})`; }
    get leaveTabLabel() { return `Leave (${this.data ? this.data.pendingLeaveCount : 0})`; }
 
    levelItems(counts, order) {
        return order.map((l) => ({ label: l, value: counts[l] || 0, color: LEVEL_COLORS[l] }));
    }
 
    get burnoutItems() {
        return this.levelItems(this.data.burnoutLevels, ['Low', 'Medium', 'High', 'Critical']);
    }
 
    get attritionItems() {
        return this.levelItems(this.data.attritionLevels, ['Low', 'Medium', 'High']);
    }
 
    get deptItems() {
        return this.data.departments.map((d) => ({
            label: d.department,
            value: d.avgBurnout,
            color: '#6366f1'
        }));
    }
}