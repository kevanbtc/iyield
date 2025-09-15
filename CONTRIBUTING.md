# Contributing Guidelines

## Overview

Thank you for your interest in contributing to the iYield project. This document outlines the procedures and requirements for contributing to this project while respecting the established ownership structure.

## ⚠️ Important Notice: Ownership Controls

This project operates under **strict ownership controls**. All contributions are subject to:
- Owner approval and review
- Security assessment and compliance check
- Adherence to governance policies
- Respect for ownership rights and intellectual property

## Contribution Process

### 1. Pre-Contribution Requirements

Before contributing, you must:
- ✅ Read and understand the ownership structure ([OWNERSHIP.md](OWNERSHIP.md))
- ✅ Review the governance framework ([GOVERNANCE.md](GOVERNANCE.md))
- ✅ Acknowledge the security requirements ([SECURITY.md](SECURITY.md))
- ✅ Sign the Contributor License Agreement (CLA)
- ✅ Obtain explicit permission from the project owner

### 2. Getting Started

```bash
# Request access (required)
# Contact: kevan@iyield.com with contribution proposal

# Once approved, you may fork the repository
git clone https://github.com/kevanbtc/iyield.git
cd iyield

# Install dependencies
npm install

# Run tests to ensure environment is working
npm test
```

### 3. Development Workflow

#### Branch Naming Convention
```bash
# Feature branches
feature/contributor-name/feature-description

# Bug fixes
fix/contributor-name/bug-description

# Documentation
docs/contributor-name/doc-description
```

#### Commit Standards
```bash
# Use conventional commits
feat: add new yield calculation method
fix: resolve ownership verification issue
docs: update API documentation
security: implement additional access controls
```

### 4. Code Standards

#### Security Requirements
- All code must pass security scans
- No hardcoded credentials or sensitive data
- Follow secure coding practices
- Implement proper input validation
- Use approved cryptographic libraries

#### Quality Standards
- Minimum 80% test coverage
- All tests must pass
- Code must pass linting checks
- Documentation for all public APIs
- Follow existing code style and patterns

#### Ownership Respect
- Do not modify ownership-related code without explicit permission
- Respect existing access controls and permissions
- Do not bypass or circumvent security measures
- Maintain audit trails for all changes

### 5. Review Process

#### Automated Checks
1. **Security Scan**: Automated vulnerability assessment
2. **Test Suite**: Complete test suite execution
3. **Lint Check**: Code style and quality verification
4. **Coverage Check**: Test coverage validation

#### Manual Review Process
1. **Owner Review**: Required for all contributions
2. **Security Review**: Security assessment by designated security lead  
3. **Governance Review**: Major changes require governance council input
4. **Compliance Check**: Ensure regulatory compliance

#### Review Criteria
- ✅ Code quality and maintainability
- ✅ Security implications assessment
- ✅ Alignment with project goals
- ✅ Respect for ownership structure
- ✅ Compliance with all policies

### 6. Submission Guidelines

#### Pull Request Template
```markdown
## Contribution Summary
Brief description of changes

## Owner Permission
- [ ] Explicit owner approval obtained
- [ ] CLA signed and on file

## Security Checklist  
- [ ] No sensitive data included
- [ ] Security scan passed
- [ ] Access controls respected

## Testing
- [ ] All tests pass
- [ ] New tests added for new features
- [ ] Coverage threshold maintained

## Documentation
- [ ] Code documented
- [ ] README updated if needed
- [ ] CHANGELOG updated

## Ownership Compliance
- [ ] Ownership rights respected
- [ ] No unauthorized modifications
- [ ] Audit trail maintained
```

### 7. Types of Contributions

#### Welcomed Contributions (with owner approval)
- Bug fixes for non-security issues
- Performance improvements
- Documentation enhancements
- Test coverage improvements
- Feature enhancements (pre-approved)

#### Restricted Contributions
- Security-related changes (owner/security team only)
- Ownership or governance modifications
- Infrastructure or deployment changes
- Core architecture modifications
- Access control or authentication changes

#### Prohibited Contributions
- Unauthorized access attempts
- Circumvention of security measures
- Ownership structure modifications
- Intellectual property violations
- Non-compliant code or practices

### 8. Recognition and Attribution

#### Contributor Recognition
- Contributors will be acknowledged in the project
- Significant contributions may be highlighted
- Professional references available upon request
- Community recognition for valuable contributions

#### Intellectual Property
- All contributions become part of the project IP
- Contributors retain attribution rights
- Commercial usage rights remain with project owner
- License terms apply to all contributions

### 9. Communication Channels

#### Primary Contacts
- **Project Owner**: [kevan@iyield.com](mailto:kevan@iyield.com)
- **Technical Lead**: [tech-lead@iyield.com](mailto:tech-lead@iyield.com)
- **Security Team**: [security@iyield.com](mailto:security@iyield.com)

#### Guidelines for Communication
- Professional and respectful communication
- Clear and detailed technical discussions  
- Respect for time and priorities
- Follow established communication protocols

### 10. Legal and Compliance

#### Contributor License Agreement (CLA)
All contributors must sign a CLA that includes:
- Grant of rights to use contributions
- Assurance of original work
- Compliance with project policies
- Respect for ownership structure

#### Compliance Requirements
- All applicable laws and regulations
- Export control regulations (if applicable)
- Industry-specific compliance requirements
- Corporate policies and procedures

### 11. Emergency Procedures

#### Security Incidents
If you discover a security vulnerability:
1. **DO NOT** create a public issue
2. Contact [security@iyield.com](mailto:security@iyield.com) immediately
3. Provide detailed information privately
4. Follow responsible disclosure practices

#### Urgent Issues
For urgent non-security issues:
1. Contact the project owner directly
2. Provide clear impact assessment
3. Suggest immediate mitigation steps
4. Follow up with formal documentation

## Code of Conduct

### Expected Behavior
- Professional and respectful interactions
- Constructive feedback and collaboration
- Respect for project ownership and governance
- Compliance with all policies and procedures

### Unacceptable Behavior
- Harassment or discriminatory behavior
- Unauthorized access attempts
- Violation of ownership rights
- Non-compliance with security policies
- Disruptive or unprofessional conduct

### Enforcement
- Violations will be addressed promptly
- Appropriate measures will be taken
- Serious violations may result in permanent exclusion
- Legal action may be pursued for severe violations

---

## Acknowledgments

We appreciate all contributors who respect the project's ownership structure and contribute positively to the iYield platform. Your professionalism and respect for established governance makes this project possible.

---

*By contributing to this project, you acknowledge and agree to abide by these guidelines and all associated policies.*

*Last updated: 2024*  
*Status: ENFORCED*