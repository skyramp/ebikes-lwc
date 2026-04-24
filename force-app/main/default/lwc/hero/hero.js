import { LightningElement, api, wire } from 'lwc';
import IMAGE_URL from '@salesforce/resourceUrl/bike_assets';
import getOrderCount from '@salesforce/apex/OrderController.getOrderCount';

const VIDEO = 'Video';
const IMAGE = 'Image';

/**
 * A Hero component that can display a Video or Image.
 */
export default class Hero extends LightningElement {
    @api title;
    @api slogan;
    @api buttonText;
    @api heroDetailsPosition;
    @api resourceUrl;
    @api imgOrVideo;
    @api internalResource;
    @api overlay;
    @api opacity;
    @api buttonClickProductOrFamilyName;

    /** Show total orders fulfilled as social proof */
    orderCount = 0;

    @wire(getOrderCount)
    wiredOrderCount({ data }) {
        if (data) {
            this.orderCount = data;
        }
    }

    get socialProofText() {
        return this.orderCount > 0
            ? `Join ${this.orderCount}+ happy riders`
            : '';
    }

    get resUrl() {
        if (this.isImg) {
            if (this.internalResource) {
                return IMAGE_URL + this.resourceUrl;
            }
        }
        return this.resourceUrl;
    }

    get isVideo() {
        return this.imgOrVideo === VIDEO;
    }

    get isImg() {
        return this.imgOrVideo === IMAGE;
    }

    get isOverlay() {
        return this.overlay === 'true';
    }

    // Apply CSS Class depending upon what position to put the hero text block
    get heroDetailsPositionClass() {
        if (this.heroDetailsPosition === 'left') {
            return 'c-hero-center-left';
        } else if (this.heroDetailsPosition === 'right') {
            return 'c-hero-center-right';
        }

        return 'c-hero-center-default';
    }

    renderedCallback() {
        // Update the overlay with the opacity configured by the admin in builder
        const overlay = this.template.querySelector('div');
        if (overlay) {
            overlay.style.opacity = parseInt(this.opacity, 10) / 10;
        }
    }
}
