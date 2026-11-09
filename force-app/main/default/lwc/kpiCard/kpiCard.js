import { LightningElement, api } from 'lwc';

export default class KpiCard extends LightningElement {
    @api label;
    @api value;
    @api sub;
    @api tone = 'default';

    get cardClass() {
        return 'kpi kpi-' + this.tone;
    }
}