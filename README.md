# LegacyVault

## Overview

LegacyVault is a decentralized smart contract platform built on Stacks that enables the creation and management of multigenerational NFTs with customizable time-locked transfer schedules. This platform allows users to create digital assets that can be automatically transferred to designated recipients based on either fixed dates or regular time intervals.

## Features

- **Time-Locked NFT Creation**: Create NFTs with predetermined transfer schedules
- **Flexible Scheduling Options**:
  - Fixed-date schedules with specific block heights
  - Interval-based schedules with regular time periods
- **Recipient Management**: Designate future owners for each stage of the NFT
- **Automatic Transfers**: Smart contract-managed transitions between stages
- **Public/Private Options**: Choose whether NFT details are publicly visible
- **Stage Advancement Verification**: Built-in checks for transfer eligibility

## Technical Specifications

### Contract Details
- **Contract Language**: Clarity
- **Platform**: Stacks Blockchain
- **Token Standard**: Non-Fungible Token (NFT)

### Data Structures

#### NFT Data
```clarity
{
    owner: principal,
    creator: principal,
    metadata-url: (string-utf8 256),
    creation-time: uint,
    current-stage: uint,
    is-public: bool,
    schedule-type: uint,
    interval-blocks: (optional uint),
    total-stages: uint
}
```

#### Stage Schedule
```clarity
{
    unlock-height: uint,
    recipient: (optional principal)
}
```

## Usage Guide

### Creating an NFT

#### Interval-Based NFT
```clarity
(contract-call? .legacyvault create-interval-nft 
    "https://metadata.example.com/token/1" ;; metadata URL
    u10000                                ;; interval in blocks
    u3                                    ;; total stages
    true)                                 ;; is public
```

#### Fixed Schedule NFT
```clarity
(contract-call? .legacyvault create-fixed-schedule-nft 
    "https://metadata.example.com/token/2" ;; metadata URL
    (list u100000 u200000 u300000)        ;; unlock heights
    true)                                  ;; is public
```

### Managing Recipients

```clarity
(contract-call? .legacyvault set-stage-recipient 
    u1      ;; NFT ID
    u0      ;; stage number
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) ;; recipient address
```

### Advancing Stages

```clarity
;; Check if NFT can advance to next stage
(contract-call? .legacyvault can-advance-stage? u1)

;; Advance NFT to next stage if conditions are met
(contract-call? .legacyvault advance-stage u1)
```

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | NFT not found |
| u102 | Invalid stage |
| u103 | Not unlocked |
| u104 | Invalid schedule |
| u105 | Schedule exists |

## Example Implementation

### Creating a Three-Generation NFT

1. Create an interval-based NFT that transfers every 52,560 blocks (approximately 1 year):
```clarity
(contract-call? .legacyvault create-interval-nft 
    "https://metadata.example.com/family-heirloom"
    u52560
    u3
    true)
```

2. Set up recipients for each stage:
```clarity
;; Set first recipient (child)
(contract-call? .legacyvault set-stage-recipient u1 u0 'ST1...)

;; Set second recipient (grandchild)
(contract-call? .legacyvault set-stage-recipient u1 u1 'ST2...)

;; Set third recipient (great-grandchild)
(contract-call? .legacyvault set-stage-recipient u1 u2 'ST3...)
```

## Security Considerations

1. **Ownership Verification**: All transfer operations verify current ownership
2. **Time-Lock Enforcement**: Transfers cannot occur before unlock heights
3. **Recipient Requirements**: Valid recipients must be set before stage advancement
4. **Schedule Immutability**: Transfer schedules cannot be modified after creation

## Best Practices

1. Always verify recipient addresses before setting them
2. Consider block time variations when setting intervals
3. Test stage advancement conditions before attempting transfers
4. Keep private keys secure for all scheduled recipients
5. Document and share transfer schedules with all future recipients

## Development Environment Setup

1. Install Clarinet for local development:
```bash
curl -L https://github.com/hirosystems/clarinet/releases/download/v1.0.0/clarinet-linux-x64-glibc.tar.gz | tar xz
```

2. Initialize a new project:
```bash
clarinet new legacyvault && cd legacyvault
```

3. Deploy locally for testing:
```bash
clarinet console
```

## Testing

Test cases should cover:
- NFT creation with both schedule types
- Recipient management
- Stage advancement conditions
- Error cases and security checks
- Time-lock enforcement

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit changes
4. Submit a pull request
