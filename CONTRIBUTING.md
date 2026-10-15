# Contributing

Thank you for your interest in improving Termux Media Server! Contributions, bug reports, documentation fixes, and practical suggestions are welcome.

## Before you start

- Search existing issues to avoid duplicates.
- For a significant change, open an issue first to discuss the proposed approach.
- Keep changes focused and explain the problem they solve.
- Never include passwords, tokens, private keys, personal logs, database files, or other secrets in commits.
- Do not assume every Android device supports the same Termux packages or CPU architecture. Note device and environment limitations when relevant.

## How to contribute

1. Fork this repository.
2. Create a branch for your change.
3. Make and test your changes on a compatible Termux/Android setup when possible.
4. Update the README or quick-command reference when behavior or usage changes.
5. Check shell scripts for quoting, error handling, and safe reruns.
6. Commit your changes with a clear message.
7. Open a pull request describing the change, how you tested it, and any limitations.

## Reporting bugs

When filing an issue, include the relevant details where possible:

- Android version and device architecture.
- Termux version and package source.
- The command you ran and the sanitized error output.
- What you expected and what happened instead.

Remove credentials, private addresses, personal file paths, and other sensitive information before posting logs.

## Pull request checklist

- [ ] The change has a clear purpose and is scoped appropriately.
- [ ] Documentation is updated where needed.
- [ ] Commands and scripts have been tested, or testing limitations are stated.
- [ ] No secrets, personal data, or generated runtime databases/logs are included.

## License

By submitting a contribution, you agree that your contribution is provided under the repository's [MIT License](LICENSE).
