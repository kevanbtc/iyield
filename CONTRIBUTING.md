# Contributing to iYield Protocol

Thank you for your interest in contributing to iYield Protocol! This document provides guidelines for contributing to our insurance-backed RWA tokenization platform.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for all contributors.

## Getting Started

### Prerequisites

- Node.js 18+ and npm 8+
- Git
- Basic understanding of Ethereum and smart contracts
- Familiarity with Solidity, JavaScript/TypeScript

### Development Setup

1. **Fork the repository**
   ```bash
   git clone https://github.com/your-username/iyield.git
   cd iyield
   ```

2. **Install dependencies**
   ```bash
   npm run install:all
   ```

3. **Build the project**
   ```bash
   npm run build
   ```

4. **Run tests**
   ```bash
   npm run test
   ```

## Project Structure

```
iyield/
├── contracts/          # Smart contracts (Solidity)
├── frontend/           # Next.js dashboard
├── .github/           # CI/CD workflows
├── docs/              # Documentation
└── scripts/           # Deployment scripts
```

## Development Workflow

### 1. Issue Creation

Before starting work:
- Check existing issues and PRs
- Create an issue describing the bug/feature
- Wait for maintainer feedback before starting work

### 2. Branch Naming

Use descriptive branch names:
- `feat/oracle-staleness-detection`
- `fix/compliance-registry-bug`
- `docs/update-api-documentation`

### 3. Commit Messages

Follow conventional commits:
```
type(scope): description

Examples:
feat(oracle): add staleness detection mechanism
fix(vault): resolve LTV calculation bug
docs(readme): update installation instructions
```

### 4. Pull Request Process

1. **Create Feature Branch**
   ```bash
   git checkout -b feat/your-feature-name
   ```

2. **Make Changes**
   - Write clean, documented code
   - Add tests for new functionality
   - Update documentation as needed

3. **Test Thoroughly**
   ```bash
   npm run test
   npm run build
   ```

4. **Submit Pull Request**
   - Clear title and description
   - Link related issues
   - Include testing instructions

## Smart Contract Guidelines

### Security First

- All state-changing functions must include reentrancy protection
- Use OpenZeppelin contracts when possible
- Implement proper access controls
- Add comprehensive tests for edge cases

### Code Quality

```solidity
// Good: Clear, documented function
/**
 * @dev Update LTV ratio for a position
 * @param positionId The position to update
 * @param newLTV New LTV ratio in basis points
 */
function updateLTV(uint256 positionId, uint256 newLTV) external onlyRole(ORACLE_UPDATER_ROLE) {
    require(newLTV <= MAX_LTV, "LTV too high");
    // Implementation...
}
```

### Testing Requirements

- Unit tests for all functions
- Integration tests for cross-contract interactions
- Edge case coverage (zero values, overflow, etc.)
- Gas usage optimization tests

## Frontend Guidelines

### Component Structure

```javascript
// components/MetricCard.js
import { useState, useEffect } from 'react';

export default function MetricCard({ title, value, trend }) {
  return (
    <div className="metric-card">
      <h3>{title}</h3>
      <p>{value}</p>
      {trend && <span className={`trend ${trend.type}`}>{trend.value}</span>}
    </div>
  );
}
```

### Styling

- Use Tailwind CSS utilities
- Follow existing component patterns
- Ensure responsive design
- Maintain accessibility standards

## Testing

### Smart Contracts

```bash
cd contracts
npm test                    # Run all tests
npm run test:coverage      # Generate coverage report
npm run test:gas           # Analyze gas usage
```

### Frontend

```bash
cd frontend
npm test                    # Run component tests
npm run type-check         # TypeScript validation
npm run lint              # ESLint checking
```

## Documentation

### Code Documentation

- Document all public functions and contracts
- Include parameter descriptions and return values
- Provide usage examples for complex functions

### API Documentation

- Update OpenAPI specs for new endpoints
- Include example requests/responses
- Document error codes and handling

## Security Considerations

### Smart Contract Security

- Never commit private keys or secrets
- Use role-based access control appropriately
- Implement emergency pause mechanisms
- Add circuit breakers for critical functions

### Disclosure Process

- Report security issues privately to security@iyield.io
- Do not create public issues for security vulnerabilities
- Allow time for fixes before public disclosure

## Review Process

### Automated Checks

All PRs must pass:
- Smart contract compilation
- Test suite execution
- Code linting
- Security scanning
- Gas optimization checks

### Manual Review

Maintainers will review:
- Code quality and architecture
- Security implications
- Test coverage
- Documentation completeness
- Breaking changes

### Approval Requirements

- ✅ All automated checks pass
- ✅ Code owner approval (@kevanbtc)
- ✅ Security review for smart contracts
- ✅ Documentation updates included

## Release Process

### Versioning

We follow [Semantic Versioning](https://semver.org/):
- `MAJOR.MINOR.PATCH`
- Breaking changes increment MAJOR
- New features increment MINOR
- Bug fixes increment PATCH

### Release Checklist

- [ ] All tests pass
- [ ] Documentation updated
- [ ] Security review completed
- [ ] Deployment scripts tested
- [ ] Release notes prepared

## Getting Help

### Resources

- 📖 [Documentation](https://docs.iyield.io)
- 💬 [Discord Community](https://discord.gg/iyield)
- 🐛 [Issue Tracker](https://github.com/kevanbtc/iyield/issues)

### Contact

- **General Questions**: hello@iyield.io
- **Security Issues**: security@iyield.io
- **Technical Support**: dev@iyield.io

## Recognition

Contributors are recognized in:
- GitHub contributor list
- Release notes
- Community Discord
- Annual contributor rewards

Thank you for helping make iYield Protocol the leading platform for insurance-backed RWA tokenization! 🚀