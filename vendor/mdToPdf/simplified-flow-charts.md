# Simplified Sync Flow Charts

This document provides a simplified overview of how data flows between WooCommerce and Visma Net when changes are detected, including webhook intake and dispatch. This is intended for non-technical users to understand what the sync service does.

## Overview

The sync service runs automatically every day at 03:00 (server local time) to ensure WooCommerce and Visma Net stay in sync. (If `DISABLE_SCHEDULER=true`, scheduled sync is turned off.)
It processes six types of data in order:

1. Products
2. Prices
3. Discounts
4. Users (Customers)
5. Orders
6. Stocks

## Products Sync

When products in Visma Net are updated, the sync service updates WooCommerce:

```text
syncAllProducts
  -> Get products from Visma Net
  -> For each product:
       |
       +-- New active product ---------> Create product in WooCommerce
       |
       +-- Existing product changed ---> Update product details in WooCommerce
       |
       +-- Product became inactive ----> Set product to draft status in WooCommerce
```

**What happens:** New products from Visma Net appear in WooCommerce. When product details change in Visma Net, those changes are reflected in WooCommerce. Inactive products are hidden (draft status) in WooCommerce.

## Prices Sync

When prices change in Visma Net, the sync service updates WooCommerce:

```text
syncPrices
  -> Get base prices from Visma Net
  -> For each price:
       |
       +-- New price for existing product ---> Set price in WooCommerce
       |
       +-- Price changed -------------------> Update price in WooCommerce
```

**What happens:** When Visma Net has a new or updated price, that price is immediately reflected in WooCommerce.

## Stocks Sync

When stock changes in Visma Net, the sync service updates WooCommerce product stock quantity:

```text
syncAllStocks
  -> Get inventory from Visma Net (including warehouse details)
  -> For each product:
       |
       +-- Calculate stock from available warehouse quantity ---> Set stock in WooCommerce
       |
       +-- Missing product mapping ---------------------------> Skip

syncSingleOrder
  -> Sync targeted order
  -> Extract SKUs from order lines
  -> Sync stock only for those SKUs
```

**What happens:** Scheduled sync refreshes all product stock from Visma Net at the end of the full sync run. Order-triggered sync refreshes stock only for products in the changed order to reduce load.

**Optional setting:** If `VISMA_STOCK_WAREHOUSE_ID` is set, stock quantity is calculated from that warehouse only.

## Discounts Sync

When discounts are synced from Visma Net, the service updates the Woo custom ERP endpoint:

```text
syncDiscounts
  -> Get discounts from Visma Net
  -> Look up discount type from Visma discount codes
  -> Validate each discount (required fields only)
       |
       +-- Missing required fields -----------> Skip this discount
       +-- Valid discount --------------------> Include in snapshot with type/promotional flags
  -> Send full valid snapshot to Woo endpoint
```

**What happens:** Discount data is sent as one full snapshot to WooCommerce's custom ERP API. Invalid discount rows are skipped, while valid rows continue to sync. When Visma marks a discount as promotional, that flag is included in the Woo snapshot.

## Users (Customers) Sync

The sync service keeps customer information synchronized between WooCommerce and Visma Net:

```text
syncAllUsers
  -> Check WooCommerce customers:
       |
       +-- New WooCommerce customer with Visma ID ---> Create contact in Visma Net
       |
       +-- Customer changed in Visma Net -----------> Update customer in WooCommerce
       |
       +-- Customer changed in WooCommerce ---------> Update contact in Visma Net

   -> Check Visma Net contacts:
        |
        +-- New contact in Visma Net ----------------> Create customer in WooCommerce
```

**What happens:** Customer information stays synchronized between both systems. If a customer updates their information in either system, it's reflected in the other. New customers from Visma Net are added to WooCommerce, and new WooCommerce customers with Visma customer numbers are added to Visma Net.

**Note:** When both systems have changes for the same customer, Visma Net information takes priority.

### Address Flow (within user sync)

Addresses are synced as part of user processing, with Visma customer addresses as source of truth:

```text
User sync step
  -> Resolve Visma customer number
  -> Load Visma customer addresses (invoice/main -> Woo billing, delivery/main -> Woo shipping)
  -> Compare address hash with stored address record
       |
       +-- changed or missing address record ------> Update Woo billing/shipping + upsert address record
       +-- unchanged ------------------------------> Skip address write
```

**What happens:** Woo billing and shipping addresses are refreshed from Visma customer addresses only when the canonical Visma-address payload changes.

## Orders Sync

The sync service keeps orders synchronized between WooCommerce and Visma Net:

```text
syncAllOrders
  -> Check WooCommerce orders:
       |
       +-- New order in WooCommerce ---------------> Create sales order in Visma Net
       |
       +-- Order changed in Visma Net -------------> Update order in WooCommerce

  -> Check Visma Net orders:
       |
       +-- New sales order in Visma Net -----------> Create order in WooCommerce
```

**What happens:** When a customer places an order in WooCommerce, it is created in Visma Net if the customer and all products are already mapped. When orders are created directly in Visma Net, they appear in WooCommerce. When Visma changes an existing linked order, WooCommerce is updated with Visma status, line pricing, shipping address, and stored Visma totals/order number metadata.

**Note:** When changes occur in both systems for the same order, Visma Net information takes priority.

## Webhook Processing

Incoming webhooks are first verified, then stored, and then dispatched to targeted single-entity sync functions:

```text
Woo/Visma webhook
  -> verify signature (shared helper)
  -> route handling:
       Woo: try parse JSON for id (parse errors are logged only)
       Visma: no pre-parse
  -> persist raw payload
  -> respond 200
  -> async dispatch worker
        -> Woo customer.* / order.* events -> single entity sync
        -> Visma customer/order/inventory -> single entity sync

Priority order:
1) Signature verification
2) Persistence
3) HTTP response
4) Async dispatch (failed rows are marked failed for manual replay)
```

## Summary

The sync service acts as a bridge between WooCommerce and Visma Net:

- **Products, Prices, Stocks & Discounts:** Flow from Visma Net to WooCommerce (one direction)
- **Customers:** Flow in both directions with Visma Net taking priority when conflicts occur
- **Addresses:** Flow from Visma customer address data to Woo customer billing/shipping
- **Orders:** Flow in both directions with Visma Net taking priority when conflicts occur

The sync runs automatically every day to keep both systems up to date (unless disabled by configuration).
