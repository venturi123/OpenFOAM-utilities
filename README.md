# OpenFOAM Utilities

A collection of MATLAB utilities for visualizing and processing OpenFOAM/SOWFA (Simulator for On/Offshore Wind Farm Applications) simulation data.

## Tools Included

### 1. sowfaABLSolverViewer.m

A MATLAB GUI application for visualizing atmospheric boundary layer (ABL) data from SOWFA simulations. This tool provides:

- Dynamic visualization of velocity and turbulence intensity profiles
- Time series playback capabilities
- Interactive range controls
- Height-time series analysis
- Calibration features

#### Usage:
```matlab
sowfaABLSolverViewer()             % Opens a dialog to select data folder
sowfaABLSolverViewer(data_folder)  % Directly loads data from specified folder
```

The data folder should contain the following files:
- `U_mean`
- `uu_mean`
- `hLevelsCell`

### 2. probeDataViewer.m

A MATLAB GUI application for visualizing SOWFA probe data in 3D space. This tool provides:

- 3D visualization of probe locations
- Multiple view options (Top, Front, Side, 3D)
- Interactive rotation
- Customizable label frequency
- Time series data visualization (when available)

#### Usage:
```matlab
probeDataViewer()                               % Opens a dialog to select a probe data file
probeDataViewer(filename)                       % Loads the specified probe data file
probeDataViewer(matFile, 'locationsVar', 'myLocations')  % Loads data with custom variable name
```

### 3. readProbeData.m

A utility function for reading SOWFA probe data files and optionally saving them to MAT files for faster access.

#### Usage:
```matlab
[time, velocities, locations] = readProbeData(filename)  % Basic usage
[time, velocities, locations] = readProbeData(filename, 'saveToMat', true)  % Save to MAT file
```

#### Parameters:
- `filename`: Path to the probe data file
- `'saveToMat'`: Boolean flag to save data to MAT file (default: false)
- `'matFilename'`: Custom filename for the MAT file (optional)

#### Returns:
- `time`: Time steps array
- `velocities`: 3D array of velocity components (time × 3 × probes)
- `locations`: Array of probe coordinates (probes × 3)

## Requirements

- MATLAB (developed and tested with MATLAB R2020b)
- No additional toolboxes required

## License

This software is open-source and provided as-is without any warranty.

## Acknowledgments

These utilities are designed for processing data from OpenFOAM and SOWFA (Simulator for On/Offshore Wind Farm Applications) simulations. 