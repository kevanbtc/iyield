# Contributing to iYield Protocol

We welcome contributions to the iYield Protocol! This document provides guidelines for contributing to the project.

## Code of Conduct

We are committed to providing a welcoming and inclusive environment for all contributors. Please read and follow our code of conduct.

## Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn
- Git
- Basic understanding of Solidity, TypeScript, and React

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/your-username/iyield.git
   cd iyield
   ```

2. **Install Dependencies**
   ```bash
   npm run install-all
   ```

3. **Environment Setup**
   ```bash
   cp contracts/.env.example contracts/.env
   # Edit the .env file with your configuration
   ```

4. **Run Tests**
   ```bash
   cd contracts && npm test
   ```

5. **Start Development Server**
   ```bash
   npm run dev-frontend
   ```

## Development Workflow

### Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring

### Commit Messages

Follow the conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting, missing semicolons, etc.
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Updating build tasks, etc.

Examples:
```
feat(contracts): add CSV oracle consensus mechanism
fix(frontend): resolve compliance status display issue
docs(readme): update installation instructions
```

## Smart Contract Development

### Guidelines

1. **Security First**
   - All contracts must pass security audits
   - Follow OpenZeppelin patterns and best practices
   - Use established libraries when possible
   - Implement comprehensive access controls

2. **Code Quality**
   - Write comprehensive NatSpec documentation
   - Include detailed comments for complex logic
   - Follow Solidity style guide
   - Maintain gas efficiency

3. **Testing Requirements**
   - Minimum 95% test coverage
   - Include integration tests
   - Test all edge cases and error conditions
   - Include fuzzing tests for critical functions

### Contract Architecture

```
contracts/
├── core/                 # Core protocol contracts
│   ├── ERCRWACSV.sol    # Main ERC-RWA:CSV token
│   ├── CSVVault.sol     # Vault management
│   └── CSVLiquidityPool.sol # Liquidity provision
├── compliance/          # Regulatory compliance
│   └── ComplianceRegistry.sol
├── oracles/            # Price and valuation oracles
│   └── CSVOracle.sol
└── interfaces/         # Contract interfaces
```

### Deployment Process

1. **Local Testing**
   ```bash
   cd contracts
   npx hardhat test
   npx hardhat coverage
   ```

2. **Testnet Deployment**
   ```bash
   npx hardhat run scripts/deploy.js --network sepolia
   ```

3. **Mainnet Preparation**
   - Complete security audit
   - Get community approval
   - Prepare migration scripts
   - Update documentation

## Frontend Development

### Technology Stack

- **Framework**: Next.js 14 with App Router
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Web3**: Wagmi + Viem
- **Charts**: Recharts
- **Icons**: Lucide React

### Guidelines

1. **Component Structure**
   ```
   components/
   ├── ui/              # Reusable UI components
   ├── charts/          # Chart components
   ├── forms/           # Form components
   └── layout/          # Layout components
   ```

2. **Code Standards**
   - Use TypeScript for all components
   - Follow React best practices
   - Implement proper error boundaries
   - Use server components where possible
   - Maintain responsive design

3. **State Management**
   - Use React Query for server state
   - Use React hooks for local state
   - Implement proper loading states
   - Handle errors gracefully

### UI/UX Guidelines

1. **Design Principles**
   - Professional and institutional appearance
   - Clear information hierarchy
   - Accessible to users with disabilities
   - Mobile-first responsive design

2. **Compliance Interface**
   - Clear status indicators
   - Easy document upload
   - Progress tracking
   - Regulatory warnings

3. **Risk Management**
   - Visual risk indicators
   - Real-time alerts
   - Comprehensive dashboards
   - Export capabilities

## Testing

### Smart Contract Tests

```bash
cd contracts
npm test                    # Run all tests
npm run test:gas           # Test with gas reporting
npm run coverage           # Generate coverage report
```

### Frontend Tests

```bash
cd frontend
npm test                   # Run Jest tests
npm run test:e2e          # Run Playwright e2e tests
npm run lint              # Run ESLint
```

### Integration Tests

Test the full system integration:
1. Deploy contracts to local network
2. Run frontend against local contracts
3. Test complete user workflows
4. Verify compliance integrations

## Security

### Smart Contract Security

1. **Audit Requirements**
   - Professional security audit required for mainnet
   - Internal security review for all PRs
   - Automated security scanning with tools like Slither

2. **Common Vulnerabilities**
   - Reentrancy attacks
   - Integer overflow/underflow
   - Access control issues
   - Front-running attacks
   - Flash loan attacks

3. **Best Practices**
   - Use battle-tested libraries (OpenZeppelin)
   - Implement circuit breakers
   - Add time delays for critical functions
   - Use multi-signature wallets for admin functions

### Frontend Security

1. **Web3 Security**
   - Validate all user inputs
   - Sanitize data before display
   - Use secure wallet connections
   - Implement proper CORS policies

2. **Data Protection**
   - Never store private keys
   - Encrypt sensitive data
   - Implement proper session management
   - Follow GDPR compliance requirements

## Documentation

### Required Documentation

1. **Code Documentation**
   - NatSpec for all smart contracts
   - JSDoc for TypeScript functions
   - README files for each module
   - Architecture decision records (ADRs)

2. **User Documentation**
   - User guides and tutorials
   - API documentation
   - Integration guides
   - FAQ and troubleshooting

3. **Developer Documentation**
   - Setup and installation guides
   - Deployment procedures
   - Testing guidelines
   - Security best practices

### Documentation Standards

- Use clear, concise language
- Include code examples
- Provide visual diagrams where helpful
- Keep documentation up-to-date with code changes
- Use proper markdown formatting

## Review Process

### Pull Request Requirements

1. **Before Submitting**
   - Ensure all tests pass
   - Update relevant documentation
   - Follow coding standards
   - Include clear description of changes

2. **PR Template**
   ```markdown
   ## Description
   Brief description of changes
   
   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update
   
   ## Testing
   - [ ] Unit tests pass
   - [ ] Integration tests pass
   - [ ] Manual testing completed
   
   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Self-review completed
   - [ ] Documentation updated
   - [ ] No breaking changes (or documented)
   ```

3. **Review Process**
   - At least 2 approvals required
   - Security review for smart contract changes
   - UI/UX review for frontend changes
   - Documentation review for user-facing changes

### Merge Requirements

- All CI checks must pass
- No merge conflicts
- Up-to-date with main branch
- Signed commits (for mainnet releases)

## Release Process

### Versioning

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

1. **Pre-release**
   - [ ] All tests passing
   - [ ] Documentation updated
   - [ ] Security audit completed (for major releases)
   - [ ] Deployment scripts tested

2. **Release**
   - [ ] Create release branch
   - [ ] Update version numbers
   - [ ] Tag release
   - [ ] Deploy to production
   - [ ] Update documentation site

3. **Post-release**
   - [ ] Monitor for issues
   - [ ] Update changelog
   - [ ] Community announcement
   - [ ] Archive old versions

## Support

### Getting Help

- **GitHub Issues**: Bug reports and feature requests
- **Discord**: Community chat and support
- **Documentation**: Comprehensive guides and API reference
- **Email**: security@iyield.protocol (security issues only)

### Issue Templates

Use the provided issue templates for:
- Bug reports
- Feature requests
- Security vulnerabilities
- Documentation improvements

### Response Times

- **Security issues**: 24 hours
- **Bug reports**: 3-5 business days
- **Feature requests**: 1-2 weeks
- **Documentation**: 1 week

## Legal and Compliance

### Licensing

- All contributions are licensed under MIT License
- By contributing, you agree to license your work under the same terms
- Include proper license headers in new files

### Regulatory Considerations

- All contributions must maintain regulatory compliance
- Consider SEC regulations for security tokens
- Ensure KYC/AML compliance features are maintained
- Consult legal team for significant changes

### Patent Policy

- Contributors grant patent license for their contributions
- Respect existing patents and intellectual property
- Report any potential patent conflicts

## Community

### Core Values

- **Transparency**: Open source and open development
- **Security**: Security-first approach to development
- **Compliance**: Regulatory compliance by design
- **Innovation**: Pushing boundaries of DeFi and insurance

### Recognition

We recognize contributors through:
- Contributor credits in releases
- Hall of fame in documentation
- Token rewards for significant contributions
- Speaking opportunities at events

Thank you for contributing to iYield Protocol! Together, we're building the future of insurance asset tokenization.