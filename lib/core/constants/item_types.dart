// SPDX-FileCopyrightText: 2025-2026 Rizwan Mulla
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';

class FieldDefinition {
  final String key;
  final String label;
  final TextInputType keyboardType;
  final bool required;
  final bool obscure;
  final int maxLines;

  const FieldDefinition({
    required this.key,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.required = false,
    this.obscure = false,
    this.maxLines = 1,
  });
}

class ItemTypeDefinition {
  final String key;
  final String label;
  final IconData icon;
  final List<FieldDefinition> fields;

  const ItemTypeDefinition({
    required this.key,
    required this.label,
    required this.icon,
    required this.fields,
  });
}

const List<ItemTypeDefinition> itemTypes = [
  ItemTypeDefinition(
    key: 'password',
    label: 'Password',
    icon: Icons.lock_outline,
    fields: [
      FieldDefinition(
        key: 'username',
        label: 'Username / Email',
        keyboardType: TextInputType.emailAddress,
        required: true,
      ),
      FieldDefinition(
        key: 'password',
        label: 'Password',
        obscure: true,
        required: true,
      ),
      FieldDefinition(
        key: 'url',
        label: 'Website / URL',
        keyboardType: TextInputType.url,
      ),
      FieldDefinition(key: 'notes', label: 'Notes', maxLines: 3),
    ],
  ),
  ItemTypeDefinition(
    key: 'bank',
    label: 'Bank Account',
    icon: Icons.account_balance,
    fields: [
      FieldDefinition(key: 'bank_name', label: 'Bank Name', required: true),
      FieldDefinition(key: 'account_type', label: 'Account Type'),
      FieldDefinition(
        key: 'account_number',
        label: 'Account Number',
        keyboardType: TextInputType.number,
        required: true,
      ),
      FieldDefinition(key: 'ifsc_code', label: 'IFSC Code', required: true),
      FieldDefinition(key: 'branch_name', label: 'Branch Name'),
      FieldDefinition(key: 'notes', label: 'Notes', maxLines: 3),
    ],
  ),
  ItemTypeDefinition(
    key: 'card',
    label: 'Card',
    icon: Icons.credit_card,
    fields: [
      FieldDefinition(key: 'cardholder_name', label: 'Cardholder Name'),
      FieldDefinition(
        key: 'number',
        label: 'Card Number',
        keyboardType: TextInputType.number,
        obscure: true,
        required: true,
      ),
      FieldDefinition(
        key: 'expiry',
        label: 'Expiry (MM/YY)',
        obscure: true,
        required: true,
      ),
      FieldDefinition(key: 'issuer', label: 'Issuer / Bank'),
      FieldDefinition(
        key: 'cvv',
        label: 'CVV',
        keyboardType: TextInputType.number,
        obscure: true,
      ),
      FieldDefinition(key: 'notes', label: 'Notes', maxLines: 3),
    ],
  ),
  ItemTypeDefinition(
    key: 'document',
    label: 'Document',
    icon: Icons.badge_outlined,
    fields: [
      FieldDefinition(key: 'scans', label: 'Scanned Pages'),
      FieldDefinition(key: 'document_id', label: 'Document ID'),
      FieldDefinition(key: 'notes', label: 'Notes', maxLines: 3),
    ],
  ),
  ItemTypeDefinition(
    key: 'note',
    label: 'Secure Note',
    icon: Icons.note_alt_outlined,
    fields: [
      FieldDefinition(key: 'note', label: 'Note', maxLines: 6, required: true),
    ],
  ),
  ItemTypeDefinition(
    key: 'wifi',
    label: 'Wi-Fi Network',
    icon: Icons.wifi_rounded,
    fields: [
      FieldDefinition(
        key: 'ssid',
        label: 'Network Name (SSID)',
        required: true,
      ),
      FieldDefinition(
        key: 'wifi_password',
        label: 'Wi-Fi Password',
        obscure: true,
      ),
      FieldDefinition(key: 'security_type', label: 'Security Type'),
      FieldDefinition(key: 'notes', label: 'Notes', maxLines: 3),
    ],
  ),
  ItemTypeDefinition(
    key: 'api_key',
    label: 'API Credential',
    icon: Icons.vpn_key_outlined,
    fields: [
      FieldDefinition(
        key: 'api_service',
        label: 'Service / Provider',
        required: true,
      ),
      FieldDefinition(
        key: 'api_key_value',
        label: 'API Key / Token',
        obscure: true,
        required: true,
      ),
      FieldDefinition(
        key: 'endpoint',
        label: 'Endpoint',
        keyboardType: TextInputType.url,
      ),
      FieldDefinition(key: 'scope', label: 'Scope / Permissions'),
      FieldDefinition(key: 'expires', label: 'Expiration Date'),
      FieldDefinition(key: 'notes', label: 'Notes', maxLines: 3),
    ],
  ),
  ItemTypeDefinition(
    key: 'recovery',
    label: 'Recovery Codes & Keys',
    icon: Icons.key_outlined,
    fields: [
      FieldDefinition(
        key: 'recovery_service',
        label: 'Service / Account',
        required: true,
      ),
      FieldDefinition(
        key: 'recovery_material',
        label: 'Recovery Codes / Key (comma-separated)',
        obscure: true,
        required: true,
      ),
      FieldDefinition(key: 'notes', label: 'Notes', maxLines: 3),
    ],
  ),
  ItemTypeDefinition(
    key: 'license',
    label: 'Software License',
    icon: Icons.card_membership_outlined,
    fields: [
      FieldDefinition(key: 'license_product', label: 'Product', required: true),
      FieldDefinition(
        key: 'license_key',
        label: 'License Key',
        obscure: true,
        required: true,
      ),
      FieldDefinition(key: 'version', label: 'Version'),
      FieldDefinition(key: 'purchase_date', label: 'Purchase Date'),
      FieldDefinition(key: 'notes', label: 'Notes', maxLines: 3),
    ],
  ),
];

ItemTypeDefinition typeByKey(String key) {
  return itemTypes.firstWhere(
    (t) => t.key == key,
    orElse: () => itemTypes.first,
  );
}
