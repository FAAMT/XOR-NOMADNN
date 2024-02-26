import numpy as np

def trainMLP(p, H, m, mu, alpha, X, D, epochMax, MSETarget, rounding_precision=2):
    """
    Train a two-layer Multilayer Perceptron (MLP) neural network using the backpropagation algorithm.

    :param p: Number of inputs.
    :param H: Number of hidden neurons.
    :param m: Number of output neurons.
    :param mu: Learning-rate parameter.
    :param alpha: Momentum constant.
    :param X: input matrix. X is a (p x N) dimensional matrix, where N is the training size.
    :param D: Desired response matrix. D is a (m x N) dimensional matrix.
    :param epochMax: Maximum number of epochs to train.
    :param MSETarget: Mean square error target.
    :return: Tuple of (Wx, Wy, MSE), where Wx is the hidden layer weight matrix, Wy is the output layer weight matrix,
             and MSE is the mean square error vector.
    """
    N = X.shape[1]
    bias = -1
    X = np.vstack([bias * np.ones((1, N)), X])
    Wx = np.random.rand(H, p + 1)
    WxAnt = np.zeros((H, p + 1))
    Wy = np.random.rand(m, H + 1)
    WyAnt = np.zeros((m, H + 1))
    MSETemp = np.zeros(epochMax)

    for i in range(epochMax):
        k = np.random.permutation(N)
        X = X[:, k]
        D = D[:, k]
        V = np.dot(Wx, X)
        Z = 1 / (1 + np.exp(-V))
        S = np.vstack([bias * np.ones((1, N)), Z])
        G = np.dot(Wy, S)
        Y = 1 / (1 + np.exp(-G))
        E = D - Y
        mse = np.mean(np.mean(E ** 2))
        MSETemp[i] = mse
        print(f'epoch = {i + 1} mse = {mse}')
        if mse < MSETarget:
            MSE = MSETemp[:i + 1]
            return np.round(Wx, rounding_precision), np.round(Wy, rounding_precision), MSE

        df = Y * (1 - Y)
        dGy = df * E
        DWy = mu / N * np.dot(dGy, S.T)
        Ty = Wy
        Wy = Wy + DWy + alpha * WyAnt
        WyAnt = Ty

        df = S * (1 - S)
        dGx = df * np.dot(Wy.T, dGy)
        dGx = dGx[1:, :]
        DWx = mu / N * np.dot(dGx, X.T)
        Tx = Wx
        Wx = Wx + DWx + alpha * WxAnt
        WxAnt = Tx

        # Rounding weights after each update to simulate hardware implementation precision
        Wx = np.round(Wx, rounding_precision)
        Wy = np.round(Wy, rounding_precision)

    MSE = MSETemp
    return Wx, Wy, MSE


