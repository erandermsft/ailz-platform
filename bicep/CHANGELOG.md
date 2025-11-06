# Changelog

The latest version of the changelog can be found [here](https://github.com/Azure/AI-Landing-Zones/blob/main/bicep/CHANGELOG.md).

## 0.1.4

### Changed

- [APIM connectivity should be intenal Vnet instead of using private endpoint](https://github.com/Azure/AI-Landing-Zones/issues/21)
- [Azure Defender for AI needs to be enabled during the deployment and configuration - Bicep](https://github.com/Azure/AI-Landing-Zones/issues/27)

## 0.1.3

### Changes

- Updated password parameter configuration.

## 0.1.2

### Changes

- Fixed Linux execution permissions for preprovision.sh and postprovision.sh scripts.
- Added Azure Bastion subnet NSG with required security rules per Microsoft documentation.
- Adapted to new directory structure.

## 0.1.1

### Changes

- Adopted **Template Specs** to bypass ARM 4 MB template size limit (wrappers, pre/post provision scripts).
- Simplified and clarified `README.md`.
- Added `docs/defaults.md` with parameter defaults.
- Updated `azure.yaml` (project rename, paths, hooks).

### Breaking Changes

- None

## 0.1.0

### Changes

- Initial version


## 0.1.1

### Changes

- Adopted **Template Specs** to bypass ARM 4 MB template size limit (wrappers, pre/post provision scripts).
- Simplified and clarified `README.md`.
- Added `docs/defaults.md` with parameter defaults.
- Updated `azure.yaml` (project rename, paths, hooks).

### Breaking Changes

- None

## 0.1.0

### Changes

- Initial version
