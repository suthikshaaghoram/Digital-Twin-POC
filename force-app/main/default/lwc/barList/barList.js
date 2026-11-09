import { LightningElement, api } from 'lwc';

export default class BarList extends LightningElement {
    @api items = [];
    @api max;

    get rows() {
        const items = this.items || [];

        const top = Number(this.max) || Math.max(
            1,
            ...items.map((i) => Number(i.value) || 0)
        );

        return items.map((i) => {
            const width = Math.min(
                100,
                Math.round(((Number(i.value) || 0) / top) * 100)
            );

            return {
                label: i.label,
                value: i.value,
                style: `width: ${width}%; background: ${i.color || '#2563eb'};`
            };
        });
    }
}