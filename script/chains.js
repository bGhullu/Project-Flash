// chains.js
const chains = {
    ethereum: {
        chainId: 1,
        provider: 'https://mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID',
        explorerApi: 'https://api.etherscan.io/api',
        apiKey: 'YOUR_ETHERSCAN_API_KEY'
    },
    bsc: {
        chainId: 56,
        provider: 'https://bsc-dataseed.binance.org/',
        explorerApi: 'https://api.bscscan.com/api',
        apiKey: 'YOUR_BSCSCAN_API_KEY'
    },
    polygon: {
        chainId: 137,
        provider: 'https://polygon-rpc.com/',
        explorerApi: 'https://api.polygonscan.com/api',
        apiKey: 'YOUR_POLYGONSCAN_API_KEY'
    },
    arbitrum: {
        chainId: 42161,
        provider: 'https://arb1.arbitrum.io/rpc',
        explorerApi: 'https://api.arbiscan.io/api',
        apiKey: 'YOUR_ARBISCAN_API_KEY'
    },
    optimism: {
        chainId: 10,
        provider: 'https://mainnet.optimism.io',
        explorerApi: 'https://api-optimistic.etherscan.io/api',
        apiKey: 'YOUR_OPTIMISTIC_ETHERSCAN_API_KEY'
    },
    fantom: {
        chainId: 250,
        provider: 'https://rpcapi.fantom.network',
        explorerApi: 'https://api.ftmscan.com/api',
        apiKey: 'YOUR_FTMSCAN_API_KEY'
    },
    avalanche: {
        chainId: 43114,
        provider: 'https://api.avax.network/ext/bc/C/rpc',
        explorerApi: 'https://api.snowtrace.io/api',
        apiKey: 'YOUR_SNOWTRACE_API_KEY'
    },
    harmony: {
        chainId: 1666600000,
        provider: 'https://api.harmony.one',
        explorerApi: 'https://api.hmny.io',
        apiKey: 'YOUR_HARMONY_API_KEY'
    },
    aurora: {
        chainId: 1313161554,
        provider: 'https://mainnet.aurora.dev',
        explorerApi: 'https://explorer.mainnet.aurora.dev/api',
        apiKey: 'YOUR_AURORA_API_KEY'
    },
    moonbeam: {
        chainId: 1284,
        provider: 'https://rpc.api.moonbeam.network',
        explorerApi: 'https://api-moonbeam.moonscan.io/api',
        apiKey: 'YOUR_MOONSCAN_API_KEY'
    },
    moonriver: {
        chainId: 1285,
        provider: 'https://rpc.api.moonriver.moonbeam.network',
        explorerApi: 'https://api-moonriver.moonscan.io/api',
        apiKey: 'YOUR_MOONSCAN_API_KEY'
    },
    celo: {
        chainId: 42220,
        provider: 'https://forno.celo.org',
        explorerApi: 'https://explorer.celo.org/api',
        apiKey: 'YOUR_CELO_API_KEY'
    },
    cronos: {
        chainId: 25,
        provider: 'https://evm-cronos.crypto.org',
        explorerApi: 'https://api.cronoscan.com/api',
        apiKey: 'YOUR_CRONOSCAN_API_KEY'
    },
    boba: {
        chainId: 288,
        provider: 'https://mainnet.boba.network',
        explorerApi: 'https://blockexplorer.boba.network/api',
        apiKey: 'YOUR_BOBA_API_KEY'
    },
    kava: {
        chainId: 2222,
        provider: 'https://evm.kava.io',
        explorerApi: 'https://explorer.kava.io/api',
        apiKey: 'YOUR_KAVA_API_KEY'
    },
    metis: {
        chainId: 1088,
        provider: 'https://andromeda.metis.io/?owner=1088',
        explorerApi: 'https://api.explorer.metis.io/api',
        apiKey: 'YOUR_METIS_API_KEY'
    },
    fuse: {
        chainId: 122,
        provider: 'https://rpc.fuse.io',
        explorerApi: 'https://explorer.fuse.io/api',
        apiKey: 'YOUR_FUSE_API_KEY'
    },
    klaytn: {
        chainId: 8217,
        provider: 'https://public-node-api.klaytnapi.com/v1/cypress',
        explorerApi: 'https://scope.klaytn.com/api',
        apiKey: 'YOUR_KLAYTN_API_KEY'
    },
    gnosis: {
        chainId: 100,
        provider: 'https://rpc.gnosischain.com',
        explorerApi: 'https://blockscout.com/xdai/mainnet/api',
        apiKey: 'YOUR_GNOSIS_API_KEY'
    },
    moonbase: {
        chainId: 1287,
        provider: 'https://rpc.api.moonbase.moonbeam.network',
        explorerApi: 'https://api-moonbase.moonscan.io/api',
        apiKey: 'YOUR_MOONBASE_API_KEY'
    },
    zksync: {
        chainId: 1,
        provider: 'https://zksync2-testnet.zksync.dev',
        explorerApi: 'https://api.zksync.io/api',
        apiKey: 'YOUR_ZKSYNC_API_KEY'
    },
    scroll: {
        chainId: 534353,
        provider: 'https://rpc.scroll.io',
        explorerApi: 'https://api.scroll.io/api',
        apiKey: 'YOUR_SCROLL_API_KEY'
    },
    linea: {
        chainId: 59144,
        provider: 'https://rpc.goerli.linea.build',
        explorerApi: 'https://explorer.goerli.linea.build/api',
        apiKey: 'YOUR_LINEA_API_KEY'
    },
    base: {
        chainId: 8453,
        provider: 'https://mainnet.base.org',
        explorerApi: 'https://api.basescan.org/api',
        apiKey: 'YOUR_BASE_API_KEY'
    },
    okex: {
        chainId: 66,
        provider: 'https://exchainrpc.okex.org',
        explorerApi: 'https://www.oklink.com/api/explorer',
        apiKey: 'YOUR_OKEX_API_KEY'
    },
    aurora_testnet: {
        chainId: 1313161555,
        provider: 'https://testnet.aurora.dev',
        explorerApi: 'https://explorer.testnet.aurora.dev/api',
        apiKey: 'YOUR_AURORA_TESTNET_API_KEY'
    },
    avalanche_fuji: {
        chainId: 43113,
        provider: 'https://api.avax-test.network/ext/bc/C/rpc',
        explorerApi: 'https://api-test.snowtrace.io/api',
        apiKey: 'YOUR_SNOWTRACE_API_KEY'
    },
    polygon_mumbai: {
        chainId: 80001,
        provider: 'https://rpc-mumbai.matic.today',
        explorerApi: 'https://api-testnet.polygonscan.com/api',
        apiKey: 'YOUR_POLYGONSCAN_API_KEY'
    },
    optimism_kovan: {
        chainId: 69,
        provider: 'https://kovan.optimism.io',
        explorerApi: 'https://api-kovan-optimistic.etherscan.io/api',
        apiKey: 'YOUR_OPTIMISTIC_ETHERSCAN_API_KEY'
    },
    arbitrum_rinkeby: {
        chainId: 421611,
        provider: 'https://rinkeby.arbitrum.io/rpc',
        explorerApi: 'https://api-testnet.arbiscan.io/api',
        apiKey: 'YOUR_ARBISCAN_API_KEY'
    }
};

module.exports = chains;
