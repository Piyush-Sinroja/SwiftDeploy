# iOS CI/CD Complete Guide
## Production Grade Setup — SwiftDeploy

---

## Table of Contents

1. [Branching Strategy](#1-branching-strategy)
2. [Environment Configuration](#2-environment-configuration)
3. [Xcode Project Setup](#3-xcode-project-setup)
4. [Code Signing with Match](#4-code-signing-with-match)
5. [Fastlane Setup](#5-fastlane-setup)
6. [GitHub Actions Workflows](#6-github-actions-workflows)
7. [GitHub Repository Settings](#7-github-repository-settings)
8. [Branch Protection Rulesets](#8-branch-protection-rulesets)
9. [GitHub Permissions](#9-github-permissions)
10. [Cache Strategy](#10-cache-strategy)
11. [Security Best Practices](#11-security-best-practices)
12. [Build Optimization](#12-build-optimization)
13. [App Store Connect Setup](#13-app-store-connect-setup)
14. [TestFlight Setup](#14-testflight-setup)
15. [Release Process](#15-release-process)
16. [Hotfix Process](#16-hotfix-process)
17. [Debugging CI Failures](#17-debugging-ci-failures)
18. [Code Quality Tools](#18-code-quality-tools)
19. [Precautions & Best Practices](#19-precautions--best-practices)
20. [Quick Reference](#20-quick-reference)

---

## 1. Branching Strategy

### Branch Structure

```
main              → production code (what users have on App Store)
release/*         → release candidates (pre-production testing)
dev               → integration branch (QA testing)
feature/*         → individual feature development
fix/*             → bug fixes on dev or release
hotfix/*          → emergency production fixes (branch from main)
perf/*            → performance improvements
ci/*              → CI/CD infrastructure changes
chore/*           → maintenance, dependency updates
```

### Branch Flow

```
feature/login ──→ dev ──→ release/1.0.0 ──→ main
                              ↑                ↑
                         Stage TF         App Store
                              
hotfix/crash ────────────────────────────→ main
                                             ↓
                                        back-merge → dev
```

### Branch Rules

| Branch | Branch from | Merges to | Who |
|--------|------------|-----------|-----|
| `feature/*` | `dev` | `dev` | Developer via PR |
| `fix/*` | `dev` or `release/*` | same | Developer via PR |
| `release/*` | `dev` | `main` + `dev` | Tech lead via PR |
| `hotfix/*` | `main` | `main` + `dev` | Tech lead via PR |
| `perf/*` | `dev` | `dev` | Developer via PR |
| `ci/*` | `dev` | `dev` | Developer via PR |
| `chore/*` | `dev` | `dev` | Developer via PR |

### Commit Message Convention (Conventional Commits)

```
feat:      new feature for user
fix:       bug fix for user
ci:        CI/CD pipeline changes
chore:     maintenance, deps update
refactor:  code restructure (no behavior change)
perf:      performance improvement
test:      adding/fixing tests
docs:      documentation only
build:     build system changes
```

### PR Title Format

```
feat: add login screen with biometric authentication
fix: resolve crash on iOS 26 during app launch
ci: add automated cache cleanup workflow
chore: update Alamofire to 5.11.2
```

### PR Description Template

```markdown
## What
- Brief bullet points of what changed

## Why
- Reason for the change

## Test Plan
- [ ] Tested on iPhone simulator
- [ ] Tested on physical device
- [ ] Unit tests pass
- [ ] UI tests pass

## Notes
- Any important caveats or context
```

---

## 2. Environment Configuration

### 3 Environments

| Environment | Bundle ID | App Name | API Server |
|------------|----------|----------|-----------|
| Dev | `com.company.app.dev` | App Dev | dev-api.server.com |
| Stage/QA | `com.company.app.stage` | App QA | stage-api.server.com |
| Production | `com.company.app` | App | api.server.com |

### xcconfig File Structure

```
SwiftDeploy/Configuration/
├── Base.xcconfig      → shared across all environments
├── Dev.xcconfig       → dev-specific overrides
├── Stage.xcconfig     → stage-specific overrides
└── Prod.xcconfig      → production overrides
```

### Base.xcconfig

```
// Shared settings — inherited by all environments
IPHONEOS_DEPLOYMENT_TARGET = 17.0
MARKETING_VERSION = 1.0.0
CURRENT_PROJECT_VERSION = 1
```

### Dev.xcconfig

```
#include "Base.xcconfig"

APP_BUNDLE_ID  = com.company.app.dev
APP_NAME       = App Dev
API_BASE_URL   = https:$()/$()/dev-api.server.com
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-Dev
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG DEV INTERNAL
```

### Stage.xcconfig

```
#include "Base.xcconfig"

APP_BUNDLE_ID  = com.company.app.stage
APP_NAME       = App QA
API_BASE_URL   = https:$()/$()/stage-api.server.com
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-QA
SWIFT_ACTIVE_COMPILATION_CONDITIONS = QA INTERNAL
```

### Prod.xcconfig

```
#include "Base.xcconfig"

APP_BUNDLE_ID  = com.company.app
APP_NAME       = App
API_BASE_URL   = https:$()/$()/api.server.com
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon
SWIFT_ACTIVE_COMPILATION_CONDITIONS = PROD
```

> **NOTE:** `https:$()/$()` is xcconfig workaround for `//` which is treated as comment

### Info.plist Required Keys

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <!-- API URL from xcconfig -->
    <key>API_BASE_URL</key>
    <string>$(API_BASE_URL)</string>

    <!-- App display name on device home screen -->
    <key>CFBundleDisplayName</key>
    <string>$(APP_NAME)</string>

    <!-- App icon set name — resolves per environment -->
    <key>CFBundleIconName</key>
    <string>$(ASSETCATALOG_COMPILER_APPICON_NAME)</string>

    <!-- Encryption compliance — avoids manual review each upload -->
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
</dict>
</plist>
```

### 6 Build Configurations

```
Dev Debug    → simulator builds, debug mode
Dev Release  → device builds, dev distribution
QA Debug     → stage simulator builds
QA Release   → stage device builds for TestFlight
Prod Debug   → production simulator builds
Prod Release → production builds for App Store
```

### Compilation Conditions

```swift
// INTERNAL flag = Dev + Stage environments (not visible in production)
// Use for: debug menus, environment switcher, test accounts

#if INTERNAL
// Show environment switcher in settings
EnvironmentSwitcherView()
#endif

#if DEBUG
// Extra verbose logging
Logger.setLevel(.verbose)
#endif

#if DEV
// Dev-specific behavior
#endif
```

### Runtime Environment Switcher (INTERNAL only)

```swift
#if INTERNAL
import UIKit

enum ServerEnvironment: String, CaseIterable {
    case dev   = "https://dev-api.server.com"
    case stage = "https://stage-api.server.com"
    case prod  = "https://api.server.com"

    var displayName: String {
        switch self {
        case .dev:   return "Dev"
        case .stage: return "Stage"
        case .prod:  return "Prod"
        }
    }
}

final class EnvironmentSwitcher {
    private static let key = "selected_server_url"

    static var current: ServerEnvironment {
        get {
            let saved = UserDefaults.standard.string(forKey: key) ?? ""
            return ServerEnvironment(rawValue: saved) ?? defaultEnvironment
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    static var baseURL: String { current.rawValue }

    private static var defaultEnvironment: ServerEnvironment {
        #if DEBUG
        return .dev
        #else
        return .stage
        #endif
    }
}
#endif
```

### Config.swift (all environments)

```swift
import Foundation

enum Config {
    static let apiBaseURL: String = {
        guard let url = Bundle.main.infoDictionary?["API_BASE_URL"] as? String,
              !url.isEmpty else {
            fatalError("API_BASE_URL missing from Info.plist")
        }
        return url
    }()
}
```

---

## 3. Xcode Project Setup

### Schemes (one per environment, all Shared)

```
App-Dev    → uses Dev Debug / Dev Release
App-Stage  → uses QA Debug / QA Release
App-Prod   → uses Prod Debug / Prod Release
```

### Scheme Settings

```
Shared: YES (committed to git — required for CI)
Test action: SwiftDeployTests + SwiftDeployUITests added
Build configuration: correct per action
```

### Test Plan (.xctestplan)

```json
{
  "testTargets": [
    { "target": { "name": "AppTests" } },
    { "target": { "name": "AppUITests" } }
  ]
}
```

### project.pbxproj Critical Settings

```
// CORRECT — keeps module name stable for @testable import
PRODUCT_NAME = $(TARGET_NAME)

// CORRECT — stable Swift module name regardless of APP_NAME
PRODUCT_MODULE_NAME = AppName

// CORRECT — points to correct app binary for unit tests
TEST_HOST = "$(BUILT_PRODUCTS_DIR)/AppName.app/AppName"

// CORRECT — per environment icon
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-Dev  (Dev configs)
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-QA   (QA configs)
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon      (Prod configs)
```

### App Icons (separate per environment)

```
Assets.xcassets/
├── AppIcon.appiconset      → Production (clean, no badge)
├── AppIcon-Dev.appiconset  → Dev (colored border/badge)
└── AppIcon-QA.appiconset   → QA (different color badge)
```

Each set needs at least:
- `1024x1024` universal PNG (required)
- Dark mode variant (optional, iOS 18+)
- Tinted variant (optional, iOS 18+)

---

## 4. Code Signing with Match

### Why Match

```
Without Match:                    With Match:
- Manual cert management          - All certs in git repo
- "Works on my machine"           - Same cert everywhere
- Cert expires → everyone broken  - Rotate centrally
- New dev → manual setup (hours)  - New dev → one command
- CI → complex keychain setup     - CI → match readonly: true
```

### Setup Steps

```bash
# 1. Create private certs repository on GitHub
# e.g. github.com/yourname/app-certs (PRIVATE)

# 2. Create PAT with repo scope
# GitHub → Settings → Developer Settings → PAT

# 3. Initialize match (run once)
bundle exec fastlane match init

# 4. Create development certs
bundle exec fastlane match development \
  --app_identifier "com.company.app.dev,com.company.app.stage,com.company.app"

# 5. Create App Store certs
bundle exec fastlane match appstore \
  --app_identifier "com.company.app.stage,com.company.app"
```

### Matchfile

```ruby
git_url          ENV["MATCH_GIT_URL"]
git_basic_authorization ENV["MATCH_GIT_BASIC_AUTHORIZATION"]
storage_mode     "git"
type             "development"
app_identifier   [
  "com.company.app",
  "com.company.app.stage",
  "com.company.app.dev"
]
```

### CI Usage (readonly mode)

```ruby
# In Fastfile — CI always uses readonly
match(
  type:       "appstore",
  readonly:   ENV["CI"] == "true",
  app_identifier: [APP_ID_QA, APP_ID_PROD]
)
```

### Certs Repository Structure

```
app-certs/
├── certs/
│   ├── development/
│   │   └── *.cer (encrypted)
│   └── distribution/
│       └── *.cer (encrypted)
└── profiles/
    ├── development/
    │   └── *.mobileprovision (encrypted)
    └── appstore/
        └── *.mobileprovision (encrypted)
```

---

## 5. Fastlane Setup

### Directory Structure

```
fastlane/
├── Fastfile         → all lanes
├── Appfile          → app identifiers
├── Matchfile        → code signing config
├── Pluginfile       → plugins
├── metadata/        → App Store metadata
├── screenshots/     → App Store screenshots
└── test_output/     → test results
```

### Gemfile

```ruby
source "https://rubygems.org"

gem "fastlane", "~> 2.233.0"
gem "xcov"      # code coverage reports
```

### Appfile

```ruby
app_identifier ENV["APP_ID"] || "com.company.app"
apple_id       ENV["APPLE_ID"]
team_id        ENV["TEAM_ID"]
itc_team_id    ENV["ITC_TEAM_ID"]
```

### Constants in Fastfile

```ruby
# ─── App Identifiers ─────────────────────────────────────
APP_ID_DEV   = "com.company.app.dev"
APP_ID_QA    = "com.company.app.stage"
APP_ID_PROD  = "com.company.app"

# ─── Schemes ─────────────────────────────────────────────
SCHEME_DEV   = "App-Dev"
SCHEME_QA    = "App-Stage"
SCHEME_PROD  = "App-Prod"

# ─── Build Configurations ────────────────────────────────
CONFIG_DEV_DEBUG  = "Dev Debug"
CONFIG_DEV_REL    = "Dev Release"
CONFIG_QA_REL     = "QA Release"
CONFIG_PROD_REL   = "Prod Release"

# ─── Project ─────────────────────────────────────────────
PROJECT       = "App.xcodeproj"
USE_WORKSPACE = File.exist?("App.xcworkspace")
WORKSPACE     = "App.xcworkspace"
OUTPUT_DIR    = "build"

# ─── Test Destination ────────────────────────────────────
DESTINATION_TEST = "platform=iOS Simulator,OS=latest,name=iPhone 16 Pro"
```

### Key Lane Patterns

#### ASC API Key (never use Apple ID in CI)

```ruby
private_lane :asc_api_key do
  app_store_connect_api_key(
    key_id:                ENV["ASC_KEY_ID"],
    issuer_id:             ENV["ASC_ISSUER_ID"],
    key_content:           ENV["ASC_KEY_CONTENT"],
    is_key_content_base64: true,
    in_house:              false
  )
end
```

#### Build Number from TestFlight (never hardcode)

```ruby
private_lane :set_build_number do |options|
  api_key = options[:api_key]
  version = get_version_number(xcodeproj: PROJECT)
  latest  = latest_testflight_build_number(
    api_key:        api_key,
    app_identifier: APP_ID_QA,
    version:        version
  )
  increment_build_number(
    build_number: latest + 1,
    xcodeproj:    PROJECT
  )
end
```

#### Incremental Build with Clean Fallback

```ruby
begin
  build_app(
    clean:                                false,
    disable_package_automatic_updates:    true,
    skip_package_dependencies_resolution: ENV["CI"] == "true",
    xcargs:                               "-parallelizeTargets",
    ...
  )
rescue => ex
  UI.important("⚠️ Incremental build failed: #{ex.message}")
  UI.important("🔄 Retrying with clean build...")
  build_app(clean: true, ...)
end
```

#### Upload to App Store (correct settings)

```ruby
upload_to_app_store(
  api_key:                    api_key,
  app_identifier:             APP_ID_PROD,
  ipa:                        result[:ipa_path],
  skip_screenshots:           true,
  skip_metadata:              true,
  submit_for_review:          false,    # ALWAYS manual
  force:                      true,
  run_precheck_before_submit: false     # API key can't check IAP
)
```

#### Upload to TestFlight

```ruby
upload_to_testflight(
  api_key:                          api_key,
  app_identifier:                   APP_ID_QA,
  ipa:                              result[:ipa_path],
  skip_waiting_for_build_processing: true,
  distribute_external:              false,
  changelog:                        changelog_from_git_commits(commits_count: 10),
  beta_app_review_info: {
    contact_email:      ENV["BETA_CONTACT_EMAIL"],
    contact_phone:      ENV["BETA_CONTACT_PHONE"],
    contact_first_name: "First",
    contact_last_name:  "Last",
    demo_account_name:  "",
    demo_account_password: "",
    notes:              "Internal QA build"
  }
)
```

#### Slack Notification

```ruby
private_lane :send_slack_notification do |options|
  webhook = ENV["SLACK_WEBHOOK_URL"]
  next if webhook.nil? || webhook.to_s.strip.empty?

  slack(
    slack_url:   webhook,
    message:     options[:message],
    success:     options.fetch(:success, true),
    payload: {
      "Branch"  => git_branch,
      "Build"   => get_build_number(xcodeproj: PROJECT),
      "Version" => get_version_number(xcodeproj: PROJECT)
    }
  )
end
```

### Complete Lane List

```
Public lanes:
  lint                    → SwiftLint check
  test_unit               → unit tests + coverage
  test_ui                 → UI tests
  test_all                → all tests (local use)
  upload_testflight_stage → QA build → TestFlight
  upload_appstore_prod    → Prod build → App Store Connect
  upload_screenshots      → screenshots → App Store
  upload_metadata         → metadata → App Store
  submit_for_review       → submit to Apple review
  add_new_device          → register device in portal
  certs_dev               → sync development certs
  certs_appstore          → sync App Store certs
  bump_version            → increment version number
  build_dev               → build dev (local testing)

Private lanes:
  asc_api_key             → create API key object
  validate_env_vars       → check required secrets set
  set_build_number        → get+increment build number
  get_testflight_build_number → fetch latest TF build
  build_ipa_for_environment   → core build logic
  get_scheme              → return scheme for environment
  get_config              → return config for environment
  get_bundle_id           → return bundle ID for environment
  send_slack_notification → post to Slack
```

---

## 6. GitHub Actions Workflows

### Workflow Files

```
.github/workflows/
├── pr-checks.yml         → lint + tests on every PR
├── beta.yml              → QA TestFlight on dev merge
├── release-stage.yml     → Stage TestFlight on release merge
├── release-prod.yml      → Prod upload on tag
├── hotfix.yml            → Emergency prod build (manual)
├── submit-review.yml     → Submit to Apple (manual)
├── cleanup-cache.yml     → Cache maintenance
└── _reusable-build.yml   → Shared build steps (never direct)
```

### Complete Trigger Map

| Trigger | Workflow | Result |
|---------|----------|--------|
| PR → dev/main/release/** | pr-checks | lint + tests |
| Merge to dev | beta | QA TestFlight |
| Merge to release/** | release-stage | Stage TestFlight |
| Tag `v*.*.*-rc*` on release | release-prod | Prod TestFlight |
| Tag `v*.*.*` on main | release-prod | Prod TestFlight |
| Manual from dev | beta | QA TestFlight |
| Manual from release/* | release-stage | Stage TestFlight |
| Manual from release/* or main | release-prod | Prod TestFlight |
| Manual hotfix | hotfix | Prod TestFlight |
| Branch deleted | cleanup-cache | cache cleanup |
| Every Sunday midnight | cleanup-cache | old cache cleanup |

### pr-checks.yml — Job Flow

```
SwiftLint              (~30s)
    ↓ needs: lint (only runs if lint passes)
    ├── Unit Tests     (~6min) ─┐ parallel
    └── UI Tests       (~7min) ─┘
```

### Concurrency — Cancel on New Push

```yaml
concurrency:
  group: pr-checks-${{ github.event.pull_request.number || github.run_id }}
  cancel-in-progress: true
```

### Xcode Setup Steps (in every macOS job)

```yaml
- name: Setup Xcode
  uses: maxim-lobanov/setup-xcode@v1
  with:
    xcode-version: "26.3"

- name: List available Xcode versions
  run: ls /Applications | grep Xcode

- name: Select Xcode
  run: sudo xcode-select -s "/Applications/Xcode_26.3.app"

- name: Check Installed iOS SDKs
  run: xcodebuild -showsdks
```

### Required Environment Variables for Test Jobs

```yaml
env:
  CI: true
  FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT: 120
  FASTLANE_XCODEBUILD_SETTINGS_RETRIES: 5
```

### Artifacts Strategy

| Artifact | Uploaded | Retention |
|----------|---------|-----------|
| IPA | On success | 14 days |
| dSYM | On success | 90 days |
| fastlane-report | Always | 7 days |
| build-logs | On failure | 3 days |
| xcresult | On failure | 3 days |
| test-results | Always | 7 days |
| swiftlint-report | On failure | 3 days |

### workflow_dispatch Input Types

```yaml
workflow_dispatch:
  inputs:
    # Text input
    reason:
      description: 'Reason for trigger'
      required: true
      type: string

    # Checkbox
    clear_cache:
      description: 'Skip caches (use if build failing)'
      type: boolean
      default: false

    # Dropdown
    environment:
      description: 'Target environment'
      type: choice
      default: 'stage'
      options:
        - dev
        - stage
        - prod

    # Number
    max_age_days:
      description: 'Delete caches older than N days'
      type: number
      default: 7
```

### Reusable Build Workflow Pattern

```yaml
# _reusable-build.yml
on:
  workflow_call:
    inputs:
      lane:
        required: true
        type: string
      clear_cache:
        required: false
        type: boolean
        default: false
    secrets:
      APPLE_ID:
        required: true
      # ... all other secrets

# Calling workflow
jobs:
  build:
    uses: ./.github/workflows/_reusable-build.yml
    with:
      lane: upload_testflight_stage
      clear_cache: ${{ inputs.clear_cache }}
    secrets: inherit
```

---

## 7. GitHub Repository Settings

### Required Secrets

```
Settings → Secrets and variables → Actions → Secrets

APPLE_ID                    Apple ID email address
TEAM_ID                     10-char developer team ID
ITC_TEAM_ID                 App Store Connect team ID
ASC_KEY_ID                  API key ID (short alphanumeric)
ASC_ISSUER_ID               API key issuer UUID
ASC_KEY_CONTENT             base64-encoded .p8 file content
MATCH_GIT_URL               private certs repo URL
MATCH_PASSWORD              certs encryption password
MATCH_GIT_BASIC_AUTHORIZATION  base64 "username:PAT"
BETA_CONTACT_EMAIL          TestFlight review contact
BETA_CONTACT_PHONE          TestFlight review contact
SLACK_WEBHOOK_URL           Slack notifications (optional)
```

### How to Encode Secrets

```bash
# Encode ASC .p8 key
base64 -i ~/Downloads/AuthKey_KEYID.p8

# Encode git authorization
echo -n "github_username:personal_access_token" | base64
```

### Variables (non-sensitive)

```
Settings → Secrets and variables → Actions → Variables

XCODE_VERSION    26.3     (if using vars instead of hardcoded)
```

### Actions Permissions

```
Settings → Actions → General

Actions permissions: Allow all actions
Workflow permissions: Read and write permissions
Allow GitHub Actions to create PRs: YES (for automation)
```

---

## 8. Branch Protection Rulesets

### Create at: Settings → Rules → Rulesets

### Ruleset: Protect main (strictest)

```
Name: Protect main
Enforcement: Active
Target branch: main

Rules:
  ✅ Restrict deletions
  ✅ Require a pull request before merging
      Required approvals: 1
      Dismiss stale reviews: YES
      Require review from code owners: optional
  ✅ Require status checks to pass
      Required checks:
        - PR Checks / SwiftLint (pull_request)
        - PR Checks / Unit Tests (pull_request)
        - PR Checks / UI Tests (pull_request)
      Require branches to be up to date: YES
  ✅ Block force pushes
  ✅ Require linear history (optional)

Bypass list: empty (nobody bypasses main)
```

### Ruleset: Protect dev

```
Name: Protect dev
Enforcement: Active
Target branch: dev

Rules:
  ✅ Restrict deletions
  ✅ Require a pull request before merging
      Required approvals: 0
  ✅ Require status checks to pass
      Required checks:
        - PR Checks / SwiftLint (pull_request)
        - PR Checks / Unit Tests (pull_request)
        - PR Checks / UI Tests (pull_request)
      Require branches to be up to date: YES
  ✅ Block force pushes

Bypass list: Repository admin (emergency only)
```

### Ruleset: Protect release

```
Name: Protect release
Enforcement: Active
Target branch: release/**

Rules:
  ✅ Restrict deletions
  ✅ Require a pull request before merging
      Required approvals: 1
  ✅ Require status checks to pass
      Required checks: (add after first PR runs)
  ✅ Block force pushes

Bypass list: Repository admin
```

### Important: Check Name Format

```
GitHub Actions reports checks as:
  "Workflow Name / Job Name (event_type)"

For branch protection rules, add:
  "PR Checks / SwiftLint (pull_request)"
  "PR Checks / Unit Tests (pull_request)"
  "PR Checks / UI Tests (pull_request)"

IMPORTANT: Use search dropdown when adding checks
           Never type manually — names must match exactly
           Checks appear in dropdown after first successful run
```

### Status Check Troubleshooting

```
Problem: "Waiting for status to be reported"
Cause:   Check names in ruleset don't match reported names
Fix:     Delete existing checks → re-add from dropdown
         OR use classic branch protection rules instead
         
Problem: Dropdown shows nothing
Cause:   Checks haven't run on this branch yet
Fix:     Run PR checks first, then add to ruleset
```

---

## 9. GitHub Permissions

### Workflow Permissions

```yaml
# In workflow file — explicitly set minimum needed permissions
permissions:
  contents: read          # read repository code
  actions: write          # manage Actions (for cache cleanup)
  pull-requests: write    # comment on PRs (for coverage reports)
  checks: write           # create check runs
  security-events: write  # for CodeQL scanning
```

### Default Permissions

```yaml
# Minimum for most workflows
permissions:
  contents: read

# For cache cleanup
permissions:
  actions: write

# For PR comments (Codecov, SonarCloud)
permissions:
  contents: read
  pull-requests: write
```

### Teams and Access (Org Repos)

```
Repository Admin  → full access, bypass rules
Tech Lead team    → write access, ruleset bypass on dev/release
Developer team    → write access, no bypass
QA team           → read access, TestFlight tester
```

### Personal Access Token Scopes

```
For MATCH_GIT_BASIC_AUTHORIZATION:
  ✅ repo (full repo access to certs repo)

For CI/CD automation:
  ✅ workflow (update workflows)
  ✅ repo (read/write repo)
```

---

## 10. Cache Strategy

### Cache Types and Sizes

| Cache | Key ingredient | Typical size |
|-------|---------------|-------------|
| DerivedData | Swift + xcconfig hash | 800MB - 1.5GB |
| SPM packages | Package.resolved hash | 500-800MB |
| CocoaPods | Podfile.lock hash | varies |
| Ruby gems | Gemfile.lock hash | ~14MB |

### Cache Keys (Best Practice)

```yaml
# SPM — invalidates only when package versions change
key: ${{ env.CACHE_VERSION }}-spm-${{ runner.os }}-${{ hashFiles('**/Package.resolved') }}
restore-keys: |
  ${{ env.CACHE_VERSION }}-spm-${{ runner.os }}-

# DerivedData — per lane, per OS, per code change
key: ${{ env.CACHE_VERSION }}-derived-${{ runner.os }}-${{ inputs.lane }}-${{ hashFiles('**/*.swift', '**/*.xcconfig') }}
restore-keys: |
  ${{ env.CACHE_VERSION }}-derived-${{ runner.os }}-${{ inputs.lane }}-
  ${{ env.CACHE_VERSION }}-derived-${{ runner.os }}-
```

### Cache Version Strategy

```yaml
env:
  CACHE_VERSION: v1   # increment to bust ALL caches permanently
```

```
When to increment:
  - After major Xcode update
  - After major dependency updates
  - When cache consistently causes build failures
  - At start of new release cycle
```

### Cache Limits

```
GitHub free: 10 GB total (all repos combined per account)
Eviction: LRU (least recently used) when limit hit
Expiry: 7 days of no access
```

### Automatic Cleanup (cleanup-cache.yml)

```
Trigger 1: Branch deleted → removes that branch's caches
Trigger 2: Weekly Sunday midnight → removes caches > 7 days old
Trigger 3: Manual → removes caches > N days old

Requires: permissions: actions: write
```

### Cache Monitoring

```
Settings → Actions → Caches

Watch for:
  - Total size approaching 10 GB
  - Many old tag caches (rc1, rc2...) — safe to delete
  - Orphaned branch caches — delete merged branches
```

---

## 11. Security Best Practices

### Never Commit These

```
.env
.env.*
*.p8          (App Store Connect API key)
*.p12         (distribution certificate)
*.mobileprovision
Pods/
DerivedData/
build/
*.ipa
*.dSYM
fastlane/report.xml
```

### .gitignore Must-Haves

```gitignore
# Secrets
.env
.env.*
*.p8
*.p12

# Build artifacts
build/
*.ipa
*.dSYM

# Dependencies
Pods/
.bundle/
vendor/

# Xcode
DerivedData/
*.xcuserstate
*.xccheckout
xcuserdata/

# Fastlane output
fastlane/report.xml
fastlane/test_output/
fastlane/screenshots/
fastlane/Preview.html
```

### Secrets vs Code

```
In GitHub Secrets:          In Fastfile (hardcoded):
  APPLE_ID                    Bundle IDs
  ASC_KEY_ID                  Scheme names
  MATCH_GIT_URL               Lane names
  MATCH_PASSWORD              Contact first/last name
  SLACK_WEBHOOK_URL
  
Why hardcode bundle IDs?
  Not sensitive, never change per developer,
  simpler than managing extra secrets
```

### API Key Security

```
Role required: App Manager (NOT Admin — least privilege)
Expiry: Set 1 year, rotate annually
Store .p8 file: 1Password or similar vault
CI storage: GitHub Secrets (encrypted at rest)
Never: email, Slack, or commit the .p8 file
```

### Match Security

```
Private repo: YES (never public)
MATCH_PASSWORD: Strong, 20+ chars, store in 1Password
PAT scope: repo only (not admin)
Rotate PAT: every 6 months
Who has access: only team leads + CI
```

### Xcode Signing Settings

```
Signing: Manual (never Automatic in CI)
Development: match Development profile
Distribution: match AppStore profile

Automatic signing causes:
  - Different profiles per machine
  - CI failures with keychain issues
  - Certificate collisions in team
```

---

## 12. Build Optimization

### Fastfile Build Settings

```ruby
build_app(
  clean:                                false,   # incremental build
  include_symbols:                      true,    # keep dSYM
  disable_package_automatic_updates:    true,    # no SPM auto-update
  skip_package_dependencies_resolution: is_ci,  # skip if CI cached
  xcargs:                               "-parallelizeTargets",
)

# Clean fallback on failure
rescue => ex
  build_app(
    clean:                                true,
    skip_package_dependencies_resolution: false,
    ...
  )
```

### Build Time Expectations

| Scenario | Time |
|----------|------|
| First build (no cache) | ~8-10 min |
| DerivedData cache hit | ~3-4 min |
| SPM + DerivedData cache hit | ~2-3 min |
| Test run (no cache) | ~12-15 min |
| Test run (cache hit) | ~6-8 min |

### Simulator Configuration

```ruby
# Use destination (more reliable than device on CI)
DESTINATION_TEST = "platform=iOS Simulator,OS=latest,name=iPhone 16 Pro"

# Run tests
run_tests(
  destination: DESTINATION_TEST,
  ...
)
```

### Test Timeout Settings

```yaml
env:
  FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT: 120
  FASTLANE_XCODEBUILD_SETTINGS_RETRIES: 5
```

### Parallel Jobs

```yaml
# pr-checks: lint first, then tests in parallel
unit-tests:
  needs: lint
  # runs in parallel with ui-tests

ui-tests:
  needs: lint
  # runs in parallel with unit-tests
```

---

## 13. App Store Connect Setup

### Initial App Setup

```
1. Go to appstoreconnect.apple.com
2. Apps → + → New App
3. Fill in:
   - Platform: iOS
   - Name: Your App Name
   - Primary Language: English
   - Bundle ID: com.company.app
   - SKU: unique identifier (e.g. APPNAME2024)
   - User Access: Full Access
```

### Required App Information

```
App Information:
  - Name (max 30 chars)
  - Subtitle (max 30 chars)
  - Privacy Policy URL (required)
  - Category (primary + optional secondary)

Pricing:
  - Free or paid tier

Age Rating:
  - Answer questionnaire honestly

App Review Information:
  - Contact: first name, last name, email, phone
  - Demo account (if app requires login)
  - Notes for reviewer
```

### Screenshots Requirements

```
Required (2025+):
  iPhone 6.9"  (1320x2868 or 1290x2796)
  iPhone 6.5"  (1242x2688 or 1284x2778)

Optional:
  iPhone 5.5"  (1242x2208)
  iPad 13"     (2064x2752)
  iPad 12.9"   (2048x2732)

Rules:
  - Up to 10 screenshots per size
  - No rounded corners/device frames (use Frameit if desired)
  - Must show actual app content
  - No promotional pricing
  - Must be in app's language
```

### App Store Connect API Key Setup

```
1. Go to appstoreconnect.apple.com
2. Users and Access → Integrations → App Store Connect API
3. Click + to create key
4. Name: CI/CD Key
5. Access: App Manager
6. Download .p8 file (ONE TIME ONLY — save securely)
7. Note: Key ID, Issuer ID

Then:
  base64 -i ~/Downloads/AuthKey_KEYID.p8
  (copy output to ASC_KEY_CONTENT secret)
```

### Encryption Compliance

```
Info.plist (add this to avoid manual question each upload):

<key>ITSAppUsesNonExemptEncryption</key>
<false/>

When to use false:
  - App uses HTTPS/TLS only (URLSession, Alamofire)
  - App uses Keychain for storage
  - No custom encryption algorithms

When to use true:
  - Custom end-to-end encryption
  - Custom crypto algorithms (CryptoKit for encryption)
  - Requires ERN (Export Registration Number)
```

---

## 14. TestFlight Setup

### Internal Testers

```
Requirements:
  - Must be in your App Store Connect team
  - No review required
  - Up to 100 testers
  - Gets builds immediately

Setup:
  App → TestFlight → Internal Testing → Add Group → Add Testers
```

### External Testers

```
Requirements:
  - Can be anyone with email
  - Requires Beta App Review (Apple reviews first)
  - Up to 10,000 testers
  - Review takes 1-3 days

Setup:
  App → TestFlight → External Testing → Add Group → Add Testers
  → Submit for Beta App Review
```

### TestFlight Groups Strategy

```
Internal QA        → developers + QA team (automatic distribution)
Beta Testers       → select external users (manual invite)
Client Review      → client stakeholders (manual invite)
```

### Build Availability

```
Internal builds:   available immediately after processing (~30 min)
External builds:   available after Beta App Review (1-3 days)
Build expiry:      90 days from upload
Max builds:        100 active builds per app
```

### Fastlane Upload Settings

```ruby
upload_to_testflight(
  skip_waiting_for_build_processing: true,  # don't wait (saves CI time)
  distribute_external:               false,  # internal only
  notify_external_testers:           false,
  changelog:                         "...",  # what's new
)
```

---

## 15. Release Process

### Version Numbering

```
MAJOR.MINOR.PATCH

MAJOR → breaking change, full redesign (1.x.x → 2.0.0)
MINOR → new feature added (1.0.x → 1.1.0)
PATCH → bug fix only (1.0.0 → 1.0.1)
```

### Tag Convention

```
v1.0.0-rc1  → first release candidate (for QA testing)
v1.0.0-rc2  → second candidate (if bug found in rc1)
v1.0.1      → hotfix release tag on main
v1.1.0-rc1  → next feature release candidate
```

### Complete Release Flow

```
PHASE 1 — Feature Development
───────────────────────────────
feature branches → dev
Each merge → QA TestFlight auto-uploads
QA continuously tests features

PHASE 2 — Release Branch
───────────────────────────────
Tech lead creates: git checkout -b release/1.0.0 from dev
Bumps version: MARKETING_VERSION = 1.0.0
Each fix merged to release → Stage TestFlight auto-uploads
QA tests full release on Stage TestFlight

PHASE 3 — Production Candidate
───────────────────────────────
QA approves Stage ✅
Tech lead tags: git tag v1.0.0-rc1 on release/1.0.0
release-prod.yml triggers → Prod TestFlight uploads
QA smoke tests production build

PHASE 4 — App Store Submission
───────────────────────────────
QA approves Prod ✅
App Store Connect → select build → Submit for Review
Fill: metadata, screenshots, age rating, pricing
Apple Review (1-3 days)
Apple approves → Release (manually or scheduled)
App LIVE ✅

PHASE 5 — Post Release
───────────────────────────────
PR: release/1.0.0 → main  (source of truth for production)
PR: release/1.0.0 → dev   (back-merge — critical!)
Delete release branch
Start next feature cycle
```

### App Store Submission Checklist

```
□ Build tested on TestFlight ✅
□ QA has approved ✅
□ Screenshots added (all required sizes)
□ App description written
□ Keywords set (100 char max)
□ What's New written
□ Support URL working
□ Privacy Policy URL working
□ Age rating answered correctly
□ Category selected
□ Pricing confirmed
□ Encryption compliance set
□ Demo account provided (if login required)
□ Notes for reviewer (if complex features)
□ App Review contact info correct
```

### After Apple Approval

```
Options:
  1. Release immediately
  2. Release on specific date/time
  3. Manual release (you release when ready)

Most companies use Manual release to control timing
(avoid releasing Friday afternoon)
```

---

## 16. Hotfix Process

### When to Use

```
✅ Bug found in LIVE App Store app
✅ Users actively affected (crash, data loss, security)
✅ Cannot wait for next release cycle
✅ Fix is small and well-understood

❌ Minor cosmetic issues → wait for next release
❌ Missing features → wait for next release
❌ Performance issues (not critical) → wait
```

### Hotfix Flow

```
1. Branch from MAIN (critical — not dev)
   git checkout main && git pull
   git checkout -b hotfix/1.0.1

   WHY from main? main = what users have
   If from dev → ships unreleased features ❌

2. Fix + version bump
   Fix the bug
   MARKETING_VERSION = 1.0.1  (patch increment)

3. PR: hotfix/1.0.1 → main
   pr-checks run automatically
   1 approval required (tech lead reviews fix)
   Merge to main

4. Tag on main
   git checkout main && git pull
   git tag v1.0.1
   git push origin v1.0.1
   → release-prod.yml triggers automatically
   → Prod TestFlight upload

5. QA smoke test (30-60 min max — it's an emergency)

6. Submit to App Store Connect
   Request expedited review:
     "This build fixes a critical crash affecting all users
      on iOS 26. Please review urgently."

7. Apple expedited review (usually 1-2 hours)

8. Release immediately after approval

9. CRITICAL: Back-merge hotfix → dev
   PR: hotfix/1.0.1 → dev
   If skipped → next release reintroduces the bug ❌

10. Update team
    "Hotfix v1.0.1 live — addresses login crash on iOS 26"
```

---

## 17. Debugging CI Failures

### Step 1 — Read the Error

```
GitHub → failed run → expand failed step → read the error

Most errors are self-explanatory:
  "Unable to find module 'AppName'" → module name issue
  "Git repository is dirty"         → gitignore issue
  "Could not find test host"        → TEST_HOST issue
  "Missing required icon file"      → icon missing
```

### Step 2 — Download Artifacts

```
Failed run → Artifacts section (bottom)

build-logs-*    → full xcodebuild output
xcresult-*      → open in Xcode for detailed view
fastlane-report → which step failed and error message
test-results-*  → JUnit XML → which tests failed
```

### Step 3 — Common Issues and Fixes

#### SwiftLint Violations

```
sorted_imports:
  Fix: alphabetical order (@testable before regular imports)

empty_count:
  Fix: .count > 0 → .isEmpty or firstMatch.exists
  Note: XCUIElementQuery doesn't have .isEmpty → use firstMatch.exists

implicitly_unwrapped_optional:
  Fix: var app: XCUIApplication! → var app: XCUIApplication?

static_over_final_class:
  Fix: override class var → override static var (in final class)
```

#### Build Failures

```
Module not found:
  PRODUCT_MODULE_NAME = AppName in Base.xcconfig

TEST_HOST not found:
  TEST_HOST = "$(BUILT_PRODUCTS_DIR)/AppName.app/AppName"
  PRODUCT_NAME must equal TARGET_NAME not APP_NAME

Multiple commands produce same file:
  Cause: PRODUCT_MODULE_NAME applied to ALL targets
  Fix: Only set in xcconfig for app target scope

Scheme not configured for test action:
  Fix: Add test targets to scheme's Test action
  Add test plan with both test targets
```

#### CI-Specific Issues

```
Dirty git repository:
  Fix: Add .bundle/ and vendor/ to .gitignore

xcodebuild timeout:
  Fix: FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT: 120

Simulator not found:
  Fix: Use destination: instead of device:
       platform=iOS Simulator,OS=latest,name=iPhone 16 Pro

Precheck fails with API key:
  Fix: run_precheck_before_submit: false

Certificate not found:
  Fix: Verify match readonly: true
       Check MATCH_GIT_URL and MATCH_PASSWORD secrets
```

### Step 4 — Re-run Strategies

```
1. Re-run failed jobs only (saves time)
2. Re-run with debug logging (GitHub UI option)
3. Clear cache and rebuild:
   workflow_dispatch → clear_cache: true
4. SSH into runner (add tmate action temporarily)
```

### Step 5 — SSH into Runner (Advanced)

```yaml
- name: Debug SSH session
  uses: mxschmitt/action-tmate@v3
  if: failure()
  with:
    limit-access-to-actor: true  # only you can SSH in
```

---

## 18. Code Quality Tools

### SwiftLint (must-have)

```yaml
# .swiftlint.yml
included:
  - Sources
  - Tests

opt_in_rules:
  - empty_count
  - sorted_imports
  - force_unwrapping
  - implicitly_unwrapped_optional

disabled_rules:
  - trailing_whitespace
  - todo

line_length:
  warning: 120
  error: 200
```

### Codecov (coverage tracking)

```yaml
# In pr-checks.yml after tests
- name: Upload Coverage
  uses: codecov/codecov-action@v4
  with:
    token: ${{ secrets.CODECOV_TOKEN }}
    files: fastlane/test_output/coverage/report.xml
    fail_ci_if_error: false
```

### GitHub Code Scanning (security)

```yaml
# .github/workflows/code-scanning.yml
- name: Initialize CodeQL
  uses: github/codeql-action/init@v3
  with:
    languages: swift

- name: Perform Analysis
  uses: github/codeql-action/analyze@v3
```

### SonarCloud (full quality)

```yaml
- name: SonarCloud Scan
  uses: SonarSource/sonarcloud-github-action@master
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

### Coverage Targets (industry standard)

```
0-30%:  Very low — prioritize testing
30-60%: Acceptable for early stage
60-80%: Good — production quality target
80%+:   Excellent
100%:   Unrealistic — don't chase this
```

---

## 19. Precautions & Best Practices

### Golden Rules

```
1. NEVER push directly to main or dev
2. NEVER commit secrets or API keys
3. NEVER merge failing PR (except emergency with admin bypass)
4. NEVER auto-submit to App Store (always manual)
5. NEVER skip back-merge after hotfix or release
6. NEVER create tags on dev branch
7. NEVER force push to shared branches
8. NEVER delete main, dev, or active release branches
9. ALWAYS test on TestFlight before App Store
10. ALWAYS get QA approval before tagging for production
```

### Branch Hygiene

```
✅ Delete feature branches after merging
✅ Keep release branches until merged to main AND dev
✅ Keep hotfix branches until back-merged to dev
✅ Never work on branches others are using without coordination
✅ Pull latest from base branch frequently
✅ Short-lived feature branches (days, not weeks)
```

### Testing Standards

```
✅ Write tests for all new features
✅ Fix failing tests before merging
✅ Test on real device before release
✅ UI tests must cover critical user flows
✅ Unit tests must cover business logic
✅ Coverage should not decrease PR over PR
```

### Certificate Management

```
✅ Only tech lead regenerates certs (not every developer)
✅ Never download profiles from Xcode automatically
✅ Run match certs_dev/certs_appstore to refresh
✅ Rotate certificates annually
✅ Store MATCH_PASSWORD in team password manager
✅ Revoke old/expired certificates regularly
```

### Version Control

```
✅ Meaningful commit messages (conventional commits)
✅ One PR per feature/fix (not massive multi-feature PRs)
✅ PR size: under 400 lines changed (easier review)
✅ Always request at least 1 review for significant changes
✅ Link PR to ticket/issue
✅ Keep commit history clean (squash merge for features)
```

### CI Maintenance

```
✅ Keep Xcode version in sync between local and CI
✅ Update fastlane regularly (bundle update fastlane)
✅ Monitor cache usage weekly
✅ Clean up old tags periodically
✅ Review and update CACHE_VERSION each major release
✅ Test manual workflow triggers quarterly
✅ Rotate GitHub PAT every 6 months
✅ Review team access permissions quarterly
```

### Performance

```
✅ lint runs first — fails fast, saves test time
✅ unit + UI tests run parallel
✅ Cancel in-progress on new push (concurrency)
✅ Incremental builds with clean fallback
✅ Cache per branch, per lane, per OS
✅ Weekly cache cleanup
✅ Delete branch caches on merge
```

---

## 20. Quick Reference

### Local Commands

```bash
# Code quality
bundle exec fastlane lint

# Testing
bundle exec fastlane test_unit
bundle exec fastlane test_ui
bundle exec fastlane test_all

# Building
bundle exec fastlane build_dev

# Uploading
bundle exec fastlane upload_testflight_stage
bundle exec fastlane upload_appstore_prod

# Certificates
bundle exec fastlane certs_dev
bundle exec fastlane certs_appstore

# Versioning
bundle exec fastlane bump_version version:"1.1.0"

# Device
bundle exec fastlane add_new_device
```

### Git Tag Commands

```bash
# Create and push tag
git checkout release/1.0.0
git tag v1.0.0-rc1
git push origin v1.0.0-rc1

# Hotfix tag on main
git checkout main && git pull
git tag v1.0.1
git push origin v1.0.1

# List all tags
git tag --list

# Delete wrong tag (local + remote)
git tag -d v1.0.0-rc1
git push origin --delete v1.0.0-rc1

# See tagged commits
git log --oneline --tags
```

### Cache Management

```bash
# Bust cache temporarily
workflow_dispatch → clear_cache: true

# Bust cache permanently
CACHE_VERSION: v2  (in workflow yml files)

# Manual cleanup
Actions → Cleanup Cache → Run workflow → max_age_days: 0
```

### Emergency Commands

```bash
# Hotfix branch from main
git checkout main && git pull
git checkout -b hotfix/1.0.1

# Back-merge after release
git checkout dev && git pull
git merge release/1.0.0

# Revert a tag
git tag -d v1.0.0-rc1
git push origin --delete v1.0.0-rc1
```

### Xcode Version Alignment

```
Local Xcode version MUST match CI Xcode version
Check: xcodebuild -version (local) vs workflow yml

Update CI:
  1. _reusable-build.yml: xcode-version: "26.3"
  2. pr-checks.yml: xcode-version: "26.3"
  3. Update simulator: name=iPhone 16 Pro (check runner)
```

### Environment Variable Reference

```
CI=true                                → Fastlane CI mode
FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT  → xcodebuild timeout (120)
FASTLANE_XCODEBUILD_SETTINGS_RETRIES  → retry count (5)
APPLE_ID                              → Apple ID email
TEAM_ID                               → developer team ID
ASC_KEY_ID                            → API key ID
ASC_ISSUER_ID                         → API key issuer
ASC_KEY_CONTENT                       → base64 .p8 content
MATCH_GIT_URL                         → certs repo URL
MATCH_PASSWORD                        → certs decrypt password
MATCH_GIT_BASIC_AUTHORIZATION         → base64 git auth
SLACK_WEBHOOK_URL                     → Slack webhook
BETA_CONTACT_EMAIL                    → TestFlight contact
BETA_CONTACT_PHONE                    → TestFlight contact
```

---

*Document Version: 1.0*
*Last Updated: April 2026*
*Project: SwiftDeploy*
*Author: Piyush Sinroja*
