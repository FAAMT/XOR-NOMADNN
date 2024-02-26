import numpy as np

def runMLP(X, Wx, Wy):
    """
    The matrix implementation of the two-layer Multilayer Perceptron (MLP) neural networks.

    :param X: input to the neural network. X is a (p x K) dimensional matrix, where p is the number of inputs and K >= 1.
    :param Wx: Hidden layer weight matrix. Wx is a (H x p+1) dimensional matrix.
    :param Wy: output layer weight matrix. Wy is a (m x H+1) dimensional matrix.
    :return: Y: output of the neural network. Y is a (m x K) dimensional matrix, where m is the number of output neurons and K >= 1.
    """
    # Add bias to input layer
    N = X.shape[1]
    bias = -1
    X = np.vstack([bias*np.ones((1, N)), X])
    
    # Calculate hidden layer output
    V = np.dot(Wx, X)
    Z = 1 / (1 + np.exp(-V))
    
    # Add bias to hidden layer output
    S = np.vstack([bias*np.ones((1, N)), Z])
    
    # Calculate output layer output
    G = np.dot(Wy, S)
    Y = 1 / (1 + np.exp(-G))
    
    return Y
