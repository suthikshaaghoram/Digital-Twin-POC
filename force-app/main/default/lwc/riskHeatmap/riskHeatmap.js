import { LightningElement, api } from 'lwc';

const LEVELS = [
    { name: 'Low', field: 'low', rgb: '22,163,74' },
    { name: 'Medium', field: 'medium', rgb: '245,158,11' },
    { name: 'High', field: 'high', rgb: '249,115,22' },
    { name: 'Critical', field: 'critical', rgb: '220,38,38' }
];

export default class RiskHeatmap extends LightningElement {
    @api departments = [];

    get cells() {
        const out = [
            {
                key: 'h-dept',
                text: 'Department',
                cls: 'cell head',
                style: ''
            }
        ];

        LEVELS.forEach((l) => {
            out.push({
                key: 'h-' + l.name,
                text: l.name,
                cls: 'cell head',
                style: ''
            });
        });

        (this.departments || []).forEach((d) => {
            out.push({
                key: 'd-' + d.department,
                text: d.department,
                cls: 'cell dept',
                style: ''
            });

            LEVELS.forEach((l) => {
                const n = d[l.field] || 0;
                const alpha = d.headcount
                    ? 0.1 + (0.9 * n) / d.headcount
                    : 0;

                out.push({
                    key: d.department + '-' + l.name,
                    text: n,
                    cls: 'cell',
                    style: n
                        ? `background: rgba(${l.rgb}, ${alpha.toFixed(2)});`
                        : ''
                });
            });
        });

        return out;
    }
}