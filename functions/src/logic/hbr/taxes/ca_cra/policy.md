# National GST Policy

**HBR Version:** 1.0
**Last verified:** 2026-05-16
**Governing statute:** Excise Tax Act (ETA)
**Administered by:** Canada Revenue Agency (CRA)

## Overview

Federal Goods and Services Tax (GST) is a 5% value-added tax collected by the CRA on most goods and services supplied in Canada. This is the baseline consumption tax for all Canadian marketplaces. Alberta has no Provincial Sales Tax (PST), so GST at 5% is the only consumption tax applicable to transactions where both buyer and seller are in Alberta.

## GST Rate

The federal GST rate is **5%**, applied to the sale price of taxable goods and services. Some provinces combine GST with a provincial component into a Harmonized Sales Tax (HST) at higher rates, but Alberta is not an HST province. For L2LAAF marketplace transactions where the place of supply is Alberta, only the 5% GST applies.

## Registration Threshold

A business must register for a GST/HST account if its total taxable revenue from worldwide sales exceeds **$30,000 CAD** over any single calendar quarter or over four consecutive calendar quarters. Voluntary registration is permitted below this threshold and allows the business to claim Input Tax Credits (ITCs) on business expenses.

## Marketplace Platform Obligations

Effective July 1, 2021, the ETA was amended to include GST/HST provisions for digital economy businesses, including distribution platform operators. Key obligations:

- **Distribution platform operators** who facilitate taxable supplies through their platform may be required to collect and remit GST/HST on behalf of third-party sellers.
- **Place of supply rules** determine the applicable tax rate based on the customer's location, not the seller's location. For physical goods delivered in Alberta, the rate is 5% GST.
- **Record-keeping:** Platforms must maintain records of all transactions including customer location, product type, tax rate applied, and tax collected. These records must be available for CRA audit.
- **Reporting:** Platform operators facilitating supplies must report information to the CRA on third-party vendors using their platforms.

## Filing Frequency

Filing frequency is assigned by the CRA based on annual sales volume:
- Under $1.5 million: annual filing
- $1.5 million to $6 million: quarterly filing
- Over $6 million: monthly filing

## Zero-Rated and Exempt Supplies

Certain goods and services are zero-rated (taxable at 0%) or exempt from GST. Basic groceries are generally zero-rated, but alcoholic beverages are NOT zero-rated — they are fully taxable at the standard 5% GST rate. This applies to beer, wine, spirits, and all other alcoholic beverages regardless of alcohol content (above 0.5% ABV).

## Federal Excise Duty (Alcohol)

In addition to GST, alcohol products are subject to federal excise duty under the Excise Act and Excise Act, 2001. These rates are adjusted annually on April 1 based on CPI inflation, capped at 2% for the 2026-28 period. Excise duty is paid by the manufacturer/importer, not the end consumer directly, but is reflected in the wholesale price. Products at or below 0.5% ABV are not subject to excise duty.

## Digital Services Tax

The Canadian Digital Services Tax (DST), a 3% levy on gross digital services revenue, was rescinded on June 29, 2025. Bill C-15 repeals the DSTA retroactively. The DST does not apply to L2LAAF operations. GST/HST obligations remain fully in force regardless of the DST repeal.

## L2LAAF Implementation Notes

- All Kaskflow and PROOF marketplace transactions with place of supply in Alberta must collect 5% GST.
- If the marketplace expands to HST provinces (Ontario, Atlantic provinces), the system must apply destination-based HST rates (13-15%) instead of 5% GST.
- Alcohol products are always fully taxable — never zero-rated.
- The platform must track and report GST collected per transaction for CRA compliance.
- GST is calculated on the final sale price inclusive of any AGLC markup already embedded in the wholesale/retail price.

## Version Management

This HBR uses bitemporal versioning. The on-disk `rules.json` represents the current `ACTIVE` version. The full version history is maintained in Firestore at `artifacts/system_status/public/data/hbr_versions/`.

GST rate changes are rare (last changed in 2008) but when they occur, they are announced well in advance with a specific effective date. The drift agent creates a `SCHEDULED` version when a future rate change is detected. The `hst_rates_by_province` lookup table may change more frequently as provinces adjust their HST/PST rates — each provincial rate change produces a new HBR version.

Federal excise duty rates are adjusted annually on April 1. The drift agent monitors the CRA excise duty rate page for the annual adjustment announcement (typically published in February/March) and creates a `SCHEDULED` version with `valid_from` set to April 1 of the relevant year.

**Drift monitoring sources:**
- GST/HST digital economy: `https://www.canada.ca/en/revenue-agency/services/tax/businesses/topics/gst-hst-businesses/digital-economy.html` (monthly)
- Excise duty rates: `https://www.canada.ca/en/revenue-agency/services/forms-publications/publications/edrates/excise-duty-rates.html` (monthly)
