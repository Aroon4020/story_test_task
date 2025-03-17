package testutil

import (
	"testing"

	chain_selectors "github.com/smartcontractkit/chain-selectors"
	"github.com/stretchr/testify/require"
	"go.uber.org/zap/zapcore"

	"github.com/smartcontractkit/chainlink/deployment/common/changeset"
	"github.com/smartcontractkit/chainlink/deployment/common/proposalutils"
	"github.com/smartcontractkit/chainlink/deployment/common/types"

	"github.com/smartcontractkit/chainlink/deployment"
	"github.com/smartcontractkit/chainlink/deployment/environment/memory"
	"github.com/smartcontractkit/chainlink/v2/core/logger"
)

// TestChain is the chain used by the in-memory environment.
var TestChain = chain_selectors.Chain{
	EvmChainID: 90000001,
	Selector:   909606746561742123,
	Name:       "Test Chain",
	VarName:    "",
}

func NewMemoryEnv(t *testing.T, deployMCMS bool) deployment.Environment {
	lggr := logger.TestLogger(t)
	memEnvConf := memory.MemoryEnvironmentConfig{
		Chains: 1,
		Nodes:  0,
	}

	env := memory.NewMemoryEnvironment(t, lggr, zapcore.InfoLevel, memEnvConf)
	chainSelector := env.AllChainSelectors()[0]

	if deployMCMS {
		config := proposalutils.SingleGroupTimelockConfigV2(t)
		// Deploy MCMS and Timelock
		_, err := changeset.Apply(t, env, nil,
			changeset.Configure(
				deployment.CreateLegacyChangeSet(changeset.DeployMCMSWithTimelockV2),
				map[uint64]types.MCMSWithTimelockConfigV2{
					chainSelector: config,
				},
			),
		)
		require.NoError(t, err)
	}

	return env
}
