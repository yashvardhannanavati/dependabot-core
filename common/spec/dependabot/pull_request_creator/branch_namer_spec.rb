# frozen_string_literal: true

require "octokit"
require "spec_helper"
require "dependabot/dependency"
require "dependabot/dependency_file"
require "dependabot/pull_request_creator/branch_namer"

RSpec.describe Dependabot::PullRequestCreator::BranchNamer do
  subject(:namer) do
    described_class.new(
      dependencies: dependencies,
      files: files,
      target_branch: target_branch
    )
  end

  let(:dependencies) { [dependency] }
  let(:dependency) do
    Dependabot::Dependency.new(
      name: "business",
      version: "1.5.0",
      previous_version: previous_version,
      package_manager: "dummy",
      requirements: requirements,
      previous_requirements: previous_requirements
    )
  end
  let(:requirements) do
    [{ file: "Gemfile", requirement: "~> 1.5.0", groups: [], source: nil }]
  end
  let(:previous_requirements) do
    [{ file: "Gemfile", requirement: "~> 1.4.0", groups: [], source: nil }]
  end
  let(:previous_version) { "1.4.0" }
  let(:files) { [gemfile] }
  let(:target_branch) { nil }

  let(:gemfile) do
    Dependabot::DependencyFile.new(
      name: "Gemfile",
      content: fixture("ruby", "gemfiles", "Gemfile")
    )
  end

  describe "#new_branch_name" do
    subject(:new_branch_name) { namer.new_branch_name }
    it { is_expected.to eq("dependabot/dummy/business-1.5.0") }

    context "with directory" do
      let(:gemfile) do
        Dependabot::DependencyFile.new(
          name: "Gemfile",
          content: fixture("ruby", "gemfiles", "Gemfile"),
          directory: directory
        )
      end
      let(:directory) { "directory" }

      it { is_expected.to eq("dependabot/dummy/directory/business-1.5.0") }

      context "that starts with a dot" do
        let(:directory) { ".directory" }

        it "santizes the dot" do
          expect(new_branch_name).
            to eq("dependabot/dummy/dot-directory/business-1.5.0")
        end
      end
    end

    context "with a custom prefix" do
      let(:namer) do
        described_class.new(
          dependencies: dependencies,
          files: files,
          target_branch: target_branch,
          prefix: prefix
        )
      end
      let(:prefix) { "myapp" }

      it { is_expected.to eq("myapp/dummy/business-1.5.0") }
    end

    context "with a target branch" do
      let(:target_branch) { "my-branch" }

      it { is_expected.to eq("dependabot/dummy/my-branch/business-1.5.0") }
    end

    context "with a custom branch name separator" do
      let(:namer) do
        described_class.new(
          dependencies: dependencies,
          files: files,
          target_branch: target_branch,
          separator: "-"
        )
      end

      it { is_expected.to eq("dependabot-dummy-business-1.5.0") }
    end

    context "with multiple dependencies" do
      let(:dependencies) { [dependency, dep2] }
      let(:dep2) do
        Dependabot::Dependency.new(
          name: "statesman",
          version: "1.5.0",
          previous_version: "1.4.0",
          package_manager: "dummy",
          requirements: [{
            file: "Gemfile",
            requirement: "~> 1.5.0",
            groups: [],
            source: nil
          }],
          previous_requirements: [{
            file: "Gemfile",
            requirement: "~> 1.4.0",
            groups: [],
            source: nil
          }]
        )
      end

      it { is_expected.to eq("dependabot/dummy/business-and-statesman-1.5.0") }

      context "for a java property update" do
        let(:files) { [pom] }
        let(:pom) do
          Dependabot::DependencyFile.new(name: "pom.xml", content: pom_content)
        end
        let(:pom_content) do
          fixture("java", "poms", "property_pom.xml").
            gsub("4.3.12.RELEASE", "23.6-jre")
        end
        let(:dependencies) do
          [
            Dependabot::Dependency.new(
              name: "org.springframework:spring-beans",
              version: "23.6-jre",
              previous_version: "4.3.12.RELEASE",
              requirements: [{
                file: "pom.xml",
                requirement: "23.6-jre",
                groups: [],
                source: nil,
                metadata: { property_name: "springframework.version" }
              }],
              previous_requirements: [{
                file: "pom.xml",
                requirement: "4.3.12.RELEASE",
                groups: [],
                source: nil,
                metadata: { property_name: "springframework.version" }
              }],
              package_manager: "maven"
            ),
            Dependabot::Dependency.new(
              name: "org.springframework:spring-context",
              version: "23.6-jre",
              previous_version: "4.3.12.RELEASE",
              requirements: [{
                file: "pom.xml",
                requirement: "23.6-jre",
                groups: [],
                source: nil,
                metadata: { property_name: "springframework.version" }
              }],
              previous_requirements: [{
                file: "pom.xml",
                requirement: "4.3.12.RELEASE",
                groups: [],
                source: nil,
                metadata: { property_name: "springframework.version" }
              }],
              package_manager: "maven"
            )
          ]
        end

        it do
          is_expected.to eq("dependabot/maven/springframework.version-23.6-jre")
        end
      end

      context "for a dependency set update" do
        let(:dependencies) { [dependency, dep2] }
        let(:dependency) do
          Dependabot::Dependency.new(
            name: "my.group:business",
            version: "1.5.0",
            previous_version: "1.4.0",
            package_manager: "gradle",
            requirements: [{
              file: "Gemfile",
              requirement: "~> 1.5.0",
              groups: [],
              source: nil,
              metadata: {
                dependency_set: { group: "my.group", version: "1.4.0" }
              }
            }],
            previous_requirements: [{
              file: "Gemfile",
              requirement: "~> 1.4.0",
              groups: [],
              source: nil,
              metadata: {
                dependency_set: { group: "my.group", version: "1.4.0" }
              }
            }]
          )
        end
        let(:dep2) do
          Dependabot::Dependency.new(
            name: "my.group:statesman",
            version: "1.5.0",
            previous_version: "1.4.0",
            package_manager: "gradle",
            requirements: [{
              file: "Gemfile",
              requirement: "~> 1.5.0",
              groups: [],
              source: nil,
              metadata: {
                dependency_set: { group: "my.group", version: "1.4.0" }
              }
            }],
            previous_requirements: [{
              file: "Gemfile",
              requirement: "~> 1.4.0",
              groups: [],
              source: nil,
              metadata: {
                dependency_set: { group: "my.group", version: "1.4.0" }
              }
            }]
          )
        end

        it { is_expected.to eq("dependabot/gradle/my.group-1.5.0") }
      end
    end

    context "with a : in the name" do
      let(:dependency) do
        Dependabot::Dependency.new(
          name: "com.google.guava:guava",
          version: "23.6-jre",
          previous_version: "23.3-jre",
          package_manager: "java",
          requirements: [{
            file: "pom.xml",
            requirement: "23.6-jre",
            groups: [],
            source: nil
          }],
          previous_requirements: [{
            file: "pom.xml",
            requirement: "23.3-jre",
            groups: [],
            source: nil
          }]
        )
      end

      it "replaces the colon with a hyphen" do
        expect(new_branch_name).
          to eq("dependabot/java/com.google.guava-guava-23.6-jre")
      end
    end

    context "with an @ in the name" do
      let(:dependency) do
        Dependabot::Dependency.new(
          name: "@storybook/addon-knobs",
          version: "5.1.9",
          previous_version: "5.0.11",
          package_manager: "npm_and_yarn",
          requirements: []
        )
      end

      it "strips @ character" do
        expect(new_branch_name).
          to eq("dependabot/npm_and_yarn/storybook/addon-knobs-5.1.9")
      end
    end

    context "with square brackets in the name" do
      let(:dependency) do
        Dependabot::Dependency.new(
          name: "werkzeug[watchdog]",
          version: "0.16.0",
          previous_version: "0.15.0",
          package_manager: "pip",
          requirements: []
        )
      end

      it "replaces the brackets with hyphens" do
        expect(new_branch_name).
          to eq("dependabot/pip/werkzeug-watchdog-0.16.0")
      end
    end

    context "with a requirement only" do
      let(:previous_version) { nil }
      let(:requirements) do
        [{
          file: "Gemfile",
          requirement: requirement_string,
          groups: [],
          source: nil
        }]
      end
      let(:requirement_string) { "~> 1.5.0" }

      it { is_expected.to eq("dependabot/dummy/business-tw-1.5.0") }

      context "that has a trailing dot" do
        let(:requirement_string) { "^7." }
        it { is_expected.to eq("dependabot/dummy/business-tw-7") }
      end
    end

    context "with SHA-1 versions" do
      let(:dependency) do
        Dependabot::Dependency.new(
          name: "business",
          version: new_version,
          previous_version: previous_version,
          package_manager: "dummy",
          requirements: [{
            file: "Gemfile",
            requirement: nil,
            groups: [],
            source: {
              type: "git",
              url: "https://github.com/gocardless/business",
              ref: new_ref
            }
          }],
          previous_requirements: [{
            file: "Gemfile",
            requirement: nil,
            groups: [],
            source: {
              type: "git",
              url: "https://github.com/gocardless/business",
              ref: old_ref
            }
          }]
        )
      end
      let(:new_version) { "cff701b3bfb182afc99a85657d7c9f3d6c1ccce2" }
      let(:previous_version) { "2468a02a6230e59ed1232d95d1ad3ef157195b03" }
      let(:new_ref) { nil }
      let(:old_ref) { nil }

      it "truncates the version" do
        expect(new_branch_name).to eq("dependabot/dummy/business-cff701b")
      end

      context "due to a ref change" do
        let(:new_ref) { "v1.1.0" }
        let(:old_ref) { "v1.0.0" }

        it "includes the ref rather than the commit" do
          expect(new_branch_name).to eq("dependabot/dummy/business-v1.1.0")
        end

        context "for a library" do
          let(:new_version) { nil }
          let(:previous_version) { nil }

          it "includes the ref rather than the commit" do
            expect(new_branch_name).to eq("dependabot/dummy/business-v1.1.0")
          end
        end
      end
    end

    context "with a Docker digest update" do
      let(:dependency) do
        Dependabot::Dependency.new(
          name: "ubuntu",
          version: "17.10",
          previous_version: previous_version,
          package_manager: "docker",
          requirements: [{
            file: "Dockerfile",
            requirement: nil,
            groups: [],
            source: {
              type: "digest",
              digest: "sha256:18305429afa14ea462f810146ba44d4363ae76e4c8d"\
                      "fc38288cf73aa07485005"
            }
          }],
          previous_requirements: [{
            file: "Dockerfile",
            requirement: nil,
            groups: [],
            source: {
              type: "digest",
              digest: "sha256:2167a21baaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"\
                      "aaaaaaaaaaaaaaaaaaaaa"
            }
          }]
        )
      end
      let(:previous_version) { "17.10" }

      it "truncates the version" do
        expect(new_branch_name).to eq("dependabot/docker/ubuntu-1830542")
      end

      context "due to a tag change" do
        let(:previous_version) { "17.04" }

        it "includes the tag rather than the SHA" do
          expect(new_branch_name).to eq("dependabot/docker/ubuntu-17.10")
        end
      end
    end
  end
end
