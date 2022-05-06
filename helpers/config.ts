import {Network, ConfigData, Config} from './types';

const getNetworkId = (chainId: number): string => {
  const {mainnet, mumbai, polygon, rinkeby, xdai, hardhat} = Network;
  switch (chainId) {
    case 1:
      return mainnet;
    case 4:
      return rinkeby;
    case 100:
      return xdai;
    case 137:
      return polygon;
    case 80001:
      return mumbai;
    case 31137:
      return hardhat;
    default:
      return hardhat;
  }
};

const Config: Config = {
  [Network.xdai]: {
    conviction: '',
    superfluid: '',
    superToken: '',
  },
  [Network.rinkeby]: {
    conviction: '0x06b35a5e6799ab2ffdc383e81490cd72c983d5a5',
    superfluid: '0xfd0c006c16395de18d38efbcbd85b53d68366235',
    superToken: '0xe166aa0a466d7d012940c872aa0e0cd74c7bc7e9',
  },
  [Network.localhost]: {
    conviction: '0x06b35a5e6799ab2ffdc383e81490cd72c983d5a5',
    superfluid: '0xfd0c006c16395de18d38efbcbd85b53d68366235',
    superToken: '0xe166aa0a466d7d012940c872aa0e0cd74c7bc7e9',
  },
  [Network.hardhat]: {
    conviction: '0x06b35a5e6799ab2ffdc383e81490cd72c983d5a5',
    superfluid: '0xfd0c006c16395de18d38efbcbd85b53d68366235',
    superToken: '0xe166aa0a466d7d012940c872aa0e0cd74c7bc7e9',
  },
};

export const getConfig = (networkId: number): ConfigData => {
  return Config[getNetworkId(networkId)];
};

export default ConfigData;
