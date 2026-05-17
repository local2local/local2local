# Federal Interprovincial Liquor Transport Policy

**HBR Version:** 1.0
**Last verified:** 2026-05-16
**Governing statute:** Importation of Intoxicating Liquors Act, RSC 1985, c I-3

## Overview

The Importation of Intoxicating Liquors Act (IILA) is a federal statute enacted in 1928 governing the interprovincial transportation and international importation of intoxicating liquors. It gives provinces the authority to control all liquor imports into their jurisdictions by requiring that importations be made by provincial liquor authorities.

## Core Principle

All interprovincial import of intoxicating liquor must be conducted by or through the provincial liquor authority (in Alberta, the AGLC). Individuals and businesses may not transport liquor across provincial boundaries without authorization.

## Wine Personal Use Exception (2012)

Bill C-311 (Royal Assent June 28, 2012) amended the IILA to allow individuals to import wine from one province to another for personal use, subject to the receiving province's quantity limits. This exception applies to wine only — beer and spirits remain restricted. The amendment does not create exemptions from federal or provincial duties, fees, taxes, or markups. Provincial legislation must also permit the importation for the exception to be effective.

## Marketplace Implications

A marketplace platform operating in a single province (Alberta) is not directly affected by IILA restrictions, since all transactions are intra-provincial. However, if the platform expands to facilitate cross-provincial transactions, all categories of alcohol other than wine for personal use would require transport through the receiving province's liquor authority. This effectively prohibits cross-provincial marketplace alcohol delivery for beer and spirits.

## L2LAAF Implementation Notes

- Initial launch (Kaskflow, PROOF) is Alberta-only, so IILA restrictions do not block operations.
- The IILA rules are encoded in this HBR as a future expansion guardrail: the Regulatory Drift Automation agent must flag any proposed feature that would enable cross-provincial alcohol delivery.
- If multi-province expansion is pursued, the system must enforce IILA compliance at the order validation layer, blocking interprovincial alcohol orders except where both the IILA exception and receiving province's laws permit it.

## Version Management

This HBR uses bitemporal versioning. The on-disk `rules.json` represents the current `ACTIVE` version. The full version history — including `SCHEDULED` future versions and `SUPERSEDED` past versions — is maintained in Firestore at `artifacts/system_status/public/data/hbr_versions/`.

The Regulatory Drift Automation agent (Phase 45.3) monitors the IILA statute text and Canada Gazette for amendments. If the federal government announces changes to interprovincial trade restrictions with a future effective date, the agent creates a `SCHEDULED` HBR version. The daily activation cron promotes it to `ACTIVE` when the effective date arrives.

**Drift monitoring source:** `https://laws-lois.justice.gc.ca/eng/acts/i-3/FullText.html`
**Check frequency:** Monthly
