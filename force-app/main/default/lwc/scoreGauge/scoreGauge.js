import { LightningElement, api } from 'lwc';

export default class ScoreGauge extends LightningElement {

    @api label;
    @api value;
    @api levelText;
    @api type = 'default';

    get displayValue() {
        return this.value !== undefined && this.value !== null
            ? Math.round(this.value)
            : '--';
    }
}