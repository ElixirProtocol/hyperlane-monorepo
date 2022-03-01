import { expect } from 'chai';

import { BeaconProxy } from '../utils/proxy';
import { CoreDeploy } from './CoreDeploy';
import {
  VerificationInput,
  ViolationType,
  ValidatorViolation,
  ValidatorManagerViolation,
  InvariantChecker,
} from '../checks';

const emptyAddr = '0x' + '00'.repeat(20);

export class CoreInvariantChecker extends InvariantChecker<CoreDeploy> {
  constructor(deploys: CoreDeploy[]) {
    super(deploys);
  }

  async checkDeploy(deploy: CoreDeploy): Promise<void> {
    this.checkContractsDefined(deploy);
    await this.checkBeaconProxies(deploy);
    await this.checkHome(deploy);
    await this.checkReplicas(deploy);
    await this.checkGovernance(deploy);
    await this.checkXAppConnectionManager(deploy);
    await this.checkValidatorManager(deploy);
    this.checkVerificationInputs(deploy);
  }

  checkContractsDefined(deploy: CoreDeploy): void {
    const contracts = deploy.contracts;
    expect(contracts.home).to.not.be.undefined;
    expect(contracts.governanceRouter).to.not.be.undefined;
    expect(contracts.upgradeBeaconController).to.not.be.undefined;
    expect(contracts.xAppConnectionManager).to.not.be.undefined;
    expect(contracts.validatorManager).to.not.be.undefined;
    for (const domain in contracts.replicas) {
      expect(contracts.replicas[domain]).to.not.be.undefined;
    }
  }

  async checkHome(deploy: CoreDeploy): Promise<void> {
    // contracts are defined
    const home = deploy.contracts.home!.proxy;
    // validatorManager is set on Home
    const actualManager = await home.validatorManager();
    const expectedManager = deploy.contracts.validatorManager!.address;
    if (actualManager !== expectedManager) {
      const violation: ValidatorManagerViolation = {
        domain: deploy.chain.domain,
        type: ViolationType.ValidatorManager,
        actual: actualManager,
        expected: expectedManager,
      };
      this.addViolation(violation);
    }
  }

  async checkValidatorManager(deploy: CoreDeploy): Promise<void> {
    const manager = deploy.contracts.validatorManager!;

    for (const _deploy of this._deploys) {
      const expected = _deploy.validator;
      const actual = await manager.validators(_deploy.chain.domain)!;
      expect(actual).to.not.be.undefined;
      if (actual !== expected) {
        const violation: ValidatorViolation = {
          local: deploy.chain.domain,
          remote: _deploy.chain.domain,
          type: ViolationType.Validator,
          actual,
          expected,
        };
        this.addViolation(violation);
      }
    }
  }

  async checkReplicas(deploy: CoreDeploy): Promise<void> {
    // Check if the Replicas on *remote* domains are set to the validator
    // configured on our domain.
    const domain = deploy.chain.domain;
    const remoteDeploys = this._deploys.filter(
      (d) => d.chain.domain !== domain,
    );
    if (remoteDeploys.length > 0) {
      // Check that all replicas on this domain share the same implementation and
      // UpgradeBeacon.
      const replicas = Object.values(deploy.contracts.replicas);
      const implementations = replicas.map((r) => r.implementation.address);
      const identical = (a: any, b: any) => (a === b ? a : false);
      const upgradeBeacons = replicas.map((r) => r.beacon.address);
      expect(implementations.reduce(identical)).to.not.be.false;
      expect(upgradeBeacons.reduce(identical)).to.not.be.false;
    }
  }

  async checkGovernance(deploy: CoreDeploy): Promise<void> {
    expect(deploy.contracts.governanceRouter).to.not.be.undefined;

    // governanceRouter for each remote domain is registered
    const registeredRouters = await Promise.all(
      Object.keys(deploy.contracts.replicas).map((_) =>
        deploy.contracts.governanceRouter?.proxy.routers(_),
      ),
    );
    registeredRouters.map((_) => expect(_).to.not.equal(emptyAddr));

    // governor is set on governor chain, empty on others
    // TODO: assert all governance routers have the same governor domain
    const governorDomain =
      await deploy.contracts.governanceRouter?.proxy.governorDomain();
    const gov = await deploy.contracts.governanceRouter?.proxy.governor();
    const localDomain = await deploy.contracts.home?.proxy.localDomain();
    if (governorDomain == localDomain) {
      expect(gov).to.not.equal(emptyAddr);
    } else {
      expect(gov).to.equal(emptyAddr);
    }

    const owners = [
      deploy.contracts.validatorManager?.owner()!,
      deploy.contracts.xAppConnectionManager?.owner()!,
      deploy.contracts.upgradeBeaconController?.owner()!,
      deploy.contracts.home?.proxy.owner()!,
    ];
    Object.values(deploy.contracts.replicas).map((_) =>
      owners.push(_.proxy.owner()),
    );

    const expectedOwner = deploy.contracts.governanceRouter?.proxy.address;
    const actualOwners = await Promise.all(owners);
    actualOwners.map((_) => expect(_).to.equal(expectedOwner));
  }

  async checkXAppConnectionManager(deploy: CoreDeploy): Promise<void> {
    expect(deploy.contracts.xAppConnectionManager).to.not.be.undefined;
    for (const domain in deploy.contracts.replicas) {
      // replica is enrolled in xAppConnectionManager
      const enrolledReplica =
        await deploy.contracts.xAppConnectionManager?.domainToReplica(domain);
      expect(enrolledReplica).to.not.equal(emptyAddr);
    }
    // Home is set on xAppConnectionManager
    const xAppManagerHome =
      await deploy.contracts.xAppConnectionManager?.home();
    const homeAddress = deploy.contracts.home?.proxy.address;
    expect(xAppManagerHome).to.equal(homeAddress);
  }

  getVerificationInputs(deploy: CoreDeploy): VerificationInput[] {
    const inputs: VerificationInput[] = [];
    const contracts = deploy.contracts;
    inputs.push([
      'UpgradeBeaconController',
      contracts.upgradeBeaconController!,
    ]);
    inputs.push(['XAppConnectionManager', contracts.xAppConnectionManager!]);
    inputs.push(['ValidatorManager', contracts.validatorManager!]);
    const addInputsForUpgradableContract = (
      contract: BeaconProxy<any>,
      name: string,
    ) => {
      inputs.push([`${name} Implementation`, contract.implementation]);
      inputs.push([`${name} UpgradeBeacon`, contract.beacon]);
      inputs.push([`${name} Proxy`, contract.proxy]);
    };
    addInputsForUpgradableContract(contracts.home!, 'Home');
    addInputsForUpgradableContract(contracts.governanceRouter!, 'Governance');
    for (const domain in contracts.replicas) {
      addInputsForUpgradableContract(contracts.replicas[domain], 'Replica');
    }
    return inputs;
  }

  async checkBeaconProxies(deploy: CoreDeploy): Promise<void> {
    const domain = deploy.chain.domain;
    const contracts = deploy.contracts;
    // Home upgrade setup contracts are defined
    await this.checkBeaconProxyImplementation(domain, 'Home', contracts.home!);

    // GovernanceRouter upgrade setup contracts are defined
    await this.checkBeaconProxyImplementation(
      domain,
      'Governance',
      contracts.governanceRouter!,
    );

    await Promise.all(
      Object.values(contracts.replicas).map((_) =>
        this.checkBeaconProxyImplementation(domain, 'Replica', _),
      ),
    );
  }
}