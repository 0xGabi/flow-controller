import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getConfig} from '../helpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, run} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  const chainId = await hre.getChainId();

  const {conviction, superfluid, superToken} = getConfig(parseInt(chainId));

  await deploy('FlowController', {
    from: deployer,
    args: [conviction, superfluid, superToken],
    log: true,
    autoMine: true, // speed up deployment on local network (ganache, hardhat), no effect on live networks
  });

  await run('tenderly:verify');
};
export default func;
func.tags = ['FlowController'];
