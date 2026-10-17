# Contributing FAQ

Answers to common questions about contributing to Surypus.

## Table of Contents

- [General Questions](#general-questions)
- [Getting Started](#getting-started)
- [Code Contributions](#code-contributions)
- [Non-Code Contributions](#non-code-contributions)
- [Community Questions](#community-questions)
- [Legal Questions](#legal-questions)
- [Release Questions](#release-questions)

---

## General Questions

### How do I contribute to Surypus?

There are many ways to contribute:

| Contribution Type | Where to Start |
|-------------------|----------------|
| Fix a bug | Look for "good first issue" or "bug" labeled issues |
| Review a PR | Comment on open PRs, suggest improvements |
| Contribute to docs | Open a PR to CONTRIBUTING.md or docs/ |
| Help others | Answer questions in issues and discussions |

All contributions are welcome, from code to documentation to community support.

### What skills do I need?

You don't need to be an expert in Haskell or formal verification! We welcome:

- **Beginners** - Fix typos, improve docs, write tests
- **Intermediate** - Add features, refactor code, improve CI
- **Experts** - Architect new features, mentor others

### Where do I start?

1. Read [CONTRIBUTING.md](https://github.com/surypus/surypus/blob/main/CONTRIBUTING.md)
2. Set up local development environment
3. Look for issues labeled ["good first issue"](../../labels/good%20first%20issue)
4. Join [GitHub Discussions](https://github.com/surypus/surypus/discussions)

---

## Getting Started

### How do I set up Surypus locally?

See [CONTRIBUTING.md](https://github.com/surypus/surypus/blob/main/CONTRIBUTING.md#local-development) for complete setup instructions.

Quick start:

```bash
git clone https://github.com/surypus/surypus.git
cd Surypus
stack setup
stack build
stack test
```

### What if I get stuck?

Ask for help!

- Open a [GitHub Discussion](../../discussions/new?category=question)
- Comment on an existing issue
- Join our community channels

We're happy to help!

---

## Code Contributions

### How do I submit a PR?

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Write tests
5. Update documentation
6. Submit a PR

See [CONTRIBUTING.md](https://github.com/surypus/surypus/blob/main/CONTRIBUTING.md#making-contributions) for details.

### Do I need to sign a CLA?

No. By submitting a PR, you agree that your contribution will be licensed under MPL-2.0.

### What is the review process?

1. A maintainer reviews your PR
2. They may request changes
3. You make the changes
4. They approve and merge

See [CODE_REVIEW_GUIDELINES.md](https://github.com/surypus/surypus/blob/main/CODE_REVIEW_GUIDELINES.md) for review standards.

### How long does review take?

We aim to review PRs within 48 hours. If your PR hasn't been reviewed, feel free to ping in the PR comments.

### Can I contribute without writing code?

Absolutely! Great contributions include:

- Writing documentation
- Reporting bugs with detailed reproduction steps
- Suggesting new features
- Reviewing PRs
- Helping others in discussions
- Translating documentation
- Sharing the project on social media

---

## Non-Code Contributions

### How do I help with documentation?

1. Find a gap in our docs
2. Write the missing content
3. Submit a PR

Even small doc improvements are valuable!

### How do I report a bug?

1. Check if the bug is already reported
2. Open a new issue using the [bug report template](../../issues/new/choose)
3. Include: reproduction steps, expected behavior, actual behavior, environment info

### Can I suggest a feature?

Yes! Use the [feature request template](../../issues/new?template=feature_request.yml) to propose a new feature.

Be sure to explain:
- What problem you're solving
- Why the feature would be useful
- Any alternatives you've considered

---

## Community Questions

### Where do I ask questions?

- **General questions** - [GitHub Discussions](../../discussions/new?category=q-a)
- **Bug reports** - [GitHub Issues](../../issues/new/choose)
- **Feature requests** - [GitHub Issues](../../issues/new?template=feature_request.yml)
- **Security issues** - Email the security team (see [SECURITY.md](https://github.com/surypus/surypus/blob/main/SECURITY.md))

### Can I present Surypus at a conference?

Yes! We'd love to have you present Surypus at conferences, meetups, or local user groups.

Please mention it in a discussion beforehand so we can help promote it.

### Can I write a blog post about Surypus?

Absolutely! We'd love to see blog posts about Surypus.

If you write something, let us know in a discussion - we may share it!

---

## Legal Questions

### What license is Surypus under?

MPL-2.0 (Mozilla Public License 2.0). See the [LICENSE](../LICENSE) file for details.

### Can I use Surypus in my proprietary project?

Yes, MPL-2.0 allows you to use separate files in proprietary projects. However, any modifications to Surypus files must be shared.

See [LICENSE](../LICENSE) for the full terms.

### Do I retain copyright to my contributions?

Yes, you retain copyright to your contributions. By submitting a PR, you agree to license your contribution under MPL-2.0.

### What if I want to use Surypus commercially without sharing modifications?

You need a commercial license. Contact [INSERT_EMAIL] for details.

---

## Release Questions

### How often are releases made?

- **Patch releases** - As needed for bug fixes
- **Minor releases** - Monthly
- **Major releases** - As needed for breaking changes

### How do I get notified of new releases?

- Follow the [releases page](https://github.com/surypus/surypus/releases)
- Subscribe to the RSS feed
- Watch the repository on GitHub

### Will there be breaking changes?

We follow [Semantic Versioning](https://semver.org/). Breaking changes will be clearly communicated in release notes.

When possible, we will:
- Provide migration guides
- Give advance notice
- Support old versions for a reasonable time

---

## Still Have Questions?

- Open a [GitHub Discussion](../../discussions/new?category=q-a)
- Email us at [INSERT_EMAIL]
- Join our chat (link to be added)

We're here to help!

---

*Last updated: 2026-09-03*
