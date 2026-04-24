import { LightningElement, api } from 'lwc';

/**
 * A presentation component to display a Product__c sObject. The provided
 * Product__c data must contain all fields used by this component.
 */
export default class ProductTile extends LightningElement {
    /** Whether the tile is draggable. */
    @api draggable;

    _product;
    /** Product__c to display. */
    @api
    get product() {
        return this._product;
    }
    set product(value) {
        this._product = value;
        this.pictureUrl = value.Picture_URL__c;
        this.name = value.Name;
        this.msrp = value.MSRP__c;
    }

    /** Product__c field values to display. */
    pictureUrl;
    name;
    msrp;

    /** Show "New" badge for products created in the last 30 days */
    get isNew() {
        if (!this._product || !this._product.CreatedDate) return false;
        const created = new Date(this._product.CreatedDate);
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        return created > thirtyDaysAgo;
    }

    handleClick() {
        const selectedEvent = new CustomEvent('selected', {
            detail: this.product.Id
        });
        this.dispatchEvent(selectedEvent);
    }

    handleDragStart(event) {
        event.dataTransfer.setData('product', JSON.stringify(this.product));
    }
}
