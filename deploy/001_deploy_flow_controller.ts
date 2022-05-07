import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getConfig} from '../helpers';

const DECAY = String(0.9999999e18);
const MAX_RATIO = String(Math.floor(0.02e18 / (30 * 24 * 60 * 60)));
const WEIGHT = String(0.025e18);

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, run} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  const chainId = await hre.getChainId();

  const {conviction, superfluid, superToken} = getConfig(parseInt(chainId));

  await deploy('FlowController', {
    from: deployer,
    args: [conviction, superfluid, superToken, DECAY, MAX_RATIO, WEIGHT],
    log: true,
    autoMine: true, // speed up deployment on local network (ganache, hardhat), no effect on live networks
  });

  await run('tenderly:verify');
};
export default func;
func.tags = ['FlowController'];
