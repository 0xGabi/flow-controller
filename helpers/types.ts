type Address = string;

export enum Network {
  mainnet = 'mainnet',
  mumbai = 'mumbai',
  polygon = 'polygon',
  rinkeby = 'rinkeby',
  xdai = 'xdai',
  hardhat = 'hardhat',
  localhost = 'localhost',
}

export type ConfigData = {
  conviction: Address;
  superfluid: Address;
  superToken: Address;
};

export type Config = {
  [key: string]: ConfigData;
};
