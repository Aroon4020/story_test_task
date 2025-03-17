// Code generated by mockery v2.53.0. DO NOT EDIT.

package txm

import (
	context "context"

	logger "github.com/smartcontractkit/chainlink-common/pkg/logger"
	mock "github.com/stretchr/testify/mock"

	types "github.com/smartcontractkit/chainlink/v2/core/chains/evm/txm/types"
)

// mockAttemptBuilder is an autogenerated mock type for the AttemptBuilder type
type mockAttemptBuilder struct {
	mock.Mock
}

type mockAttemptBuilder_Expecter struct {
	mock *mock.Mock
}

func (_m *mockAttemptBuilder) EXPECT() *mockAttemptBuilder_Expecter {
	return &mockAttemptBuilder_Expecter{mock: &_m.Mock}
}

// NewAttempt provides a mock function with given fields: _a0, _a1, _a2, _a3
func (_m *mockAttemptBuilder) NewAttempt(_a0 context.Context, _a1 logger.Logger, _a2 *types.Transaction, _a3 bool) (*types.Attempt, error) {
	ret := _m.Called(_a0, _a1, _a2, _a3)

	if len(ret) == 0 {
		panic("no return value specified for NewAttempt")
	}

	var r0 *types.Attempt
	var r1 error
	if rf, ok := ret.Get(0).(func(context.Context, logger.Logger, *types.Transaction, bool) (*types.Attempt, error)); ok {
		return rf(_a0, _a1, _a2, _a3)
	}
	if rf, ok := ret.Get(0).(func(context.Context, logger.Logger, *types.Transaction, bool) *types.Attempt); ok {
		r0 = rf(_a0, _a1, _a2, _a3)
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(*types.Attempt)
		}
	}

	if rf, ok := ret.Get(1).(func(context.Context, logger.Logger, *types.Transaction, bool) error); ok {
		r1 = rf(_a0, _a1, _a2, _a3)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// mockAttemptBuilder_NewAttempt_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'NewAttempt'
type mockAttemptBuilder_NewAttempt_Call struct {
	*mock.Call
}

// NewAttempt is a helper method to define mock.On call
//   - _a0 context.Context
//   - _a1 logger.Logger
//   - _a2 *types.Transaction
//   - _a3 bool
func (_e *mockAttemptBuilder_Expecter) NewAttempt(_a0 interface{}, _a1 interface{}, _a2 interface{}, _a3 interface{}) *mockAttemptBuilder_NewAttempt_Call {
	return &mockAttemptBuilder_NewAttempt_Call{Call: _e.mock.On("NewAttempt", _a0, _a1, _a2, _a3)}
}

func (_c *mockAttemptBuilder_NewAttempt_Call) Run(run func(_a0 context.Context, _a1 logger.Logger, _a2 *types.Transaction, _a3 bool)) *mockAttemptBuilder_NewAttempt_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(context.Context), args[1].(logger.Logger), args[2].(*types.Transaction), args[3].(bool))
	})
	return _c
}

func (_c *mockAttemptBuilder_NewAttempt_Call) Return(_a0 *types.Attempt, _a1 error) *mockAttemptBuilder_NewAttempt_Call {
	_c.Call.Return(_a0, _a1)
	return _c
}

func (_c *mockAttemptBuilder_NewAttempt_Call) RunAndReturn(run func(context.Context, logger.Logger, *types.Transaction, bool) (*types.Attempt, error)) *mockAttemptBuilder_NewAttempt_Call {
	_c.Call.Return(run)
	return _c
}

// NewBumpAttempt provides a mock function with given fields: _a0, _a1, _a2, _a3
func (_m *mockAttemptBuilder) NewBumpAttempt(_a0 context.Context, _a1 logger.Logger, _a2 *types.Transaction, _a3 types.Attempt) (*types.Attempt, error) {
	ret := _m.Called(_a0, _a1, _a2, _a3)

	if len(ret) == 0 {
		panic("no return value specified for NewBumpAttempt")
	}

	var r0 *types.Attempt
	var r1 error
	if rf, ok := ret.Get(0).(func(context.Context, logger.Logger, *types.Transaction, types.Attempt) (*types.Attempt, error)); ok {
		return rf(_a0, _a1, _a2, _a3)
	}
	if rf, ok := ret.Get(0).(func(context.Context, logger.Logger, *types.Transaction, types.Attempt) *types.Attempt); ok {
		r0 = rf(_a0, _a1, _a2, _a3)
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(*types.Attempt)
		}
	}

	if rf, ok := ret.Get(1).(func(context.Context, logger.Logger, *types.Transaction, types.Attempt) error); ok {
		r1 = rf(_a0, _a1, _a2, _a3)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// mockAttemptBuilder_NewBumpAttempt_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'NewBumpAttempt'
type mockAttemptBuilder_NewBumpAttempt_Call struct {
	*mock.Call
}

// NewBumpAttempt is a helper method to define mock.On call
//   - _a0 context.Context
//   - _a1 logger.Logger
//   - _a2 *types.Transaction
//   - _a3 types.Attempt
func (_e *mockAttemptBuilder_Expecter) NewBumpAttempt(_a0 interface{}, _a1 interface{}, _a2 interface{}, _a3 interface{}) *mockAttemptBuilder_NewBumpAttempt_Call {
	return &mockAttemptBuilder_NewBumpAttempt_Call{Call: _e.mock.On("NewBumpAttempt", _a0, _a1, _a2, _a3)}
}

func (_c *mockAttemptBuilder_NewBumpAttempt_Call) Run(run func(_a0 context.Context, _a1 logger.Logger, _a2 *types.Transaction, _a3 types.Attempt)) *mockAttemptBuilder_NewBumpAttempt_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(context.Context), args[1].(logger.Logger), args[2].(*types.Transaction), args[3].(types.Attempt))
	})
	return _c
}

func (_c *mockAttemptBuilder_NewBumpAttempt_Call) Return(_a0 *types.Attempt, _a1 error) *mockAttemptBuilder_NewBumpAttempt_Call {
	_c.Call.Return(_a0, _a1)
	return _c
}

func (_c *mockAttemptBuilder_NewBumpAttempt_Call) RunAndReturn(run func(context.Context, logger.Logger, *types.Transaction, types.Attempt) (*types.Attempt, error)) *mockAttemptBuilder_NewBumpAttempt_Call {
	_c.Call.Return(run)
	return _c
}

// newMockAttemptBuilder creates a new instance of mockAttemptBuilder. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func newMockAttemptBuilder(t interface {
	mock.TestingT
	Cleanup(func())
}) *mockAttemptBuilder {
	mock := &mockAttemptBuilder{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}
