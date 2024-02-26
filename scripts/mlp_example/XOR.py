import numpy as np
import matplotlib.pyplot as plt
from trainMLP import trainMLP
from runMLP import runMLP

# Ensure you have the trainMLP and runMLP functions defined as previously provided

# XOR Example - Batch-Mode Training parameters
p = 2  # Number of inputs
H = 4  # Number of hidden neurons
m = 1  # Number of output neurons
mu = 10  # Learning-rate parameter
alpha = 0.001  # Momentum constant
epochMax = 400  # Maximum number of epochs to train
MSETarget = 1e-20  # Mean square error target

# XOR input and Desired output
X = np.array([[0, 1, 1, 1], [0, 1, 0, 0]])
D = np.array([[0, 0, 1, 1]])

# Train MLP
Wx, Wy, MSE = trainMLP(p, H, m, mu, alpha, X, D, epochMax, MSETarget)

# Plot MSE
plt.semilogy(MSE)  # use semilogarithmic plot for MSE
plt.xlabel('Epoch')
plt.ylabel('MSE')
plt.title('MSE vs. Epoch for XOR Example')
plt.show()

# Display Desired and MLP output
print('D =', D)
Y = runMLP(X, Wx, Wy)
print('Y =', np.round(Y, 2))  # Round for easier reading

# Save weights to files as whole numbers with 2 decimal places
np.savetxt('input_hidden_weights.txt', np.round(Wx, 2), fmt='%.2f')
np.savetxt('hidden_output_weights.txt', np.round(Wy, 2), fmt='%.2f')
