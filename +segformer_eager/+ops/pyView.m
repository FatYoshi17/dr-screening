function Y = pyView(X, shape)
%PYVIEW Reshapes the input tensor into the dimensions given by shape.

%   Copyright 2022-2023 The MathWorks, Inc.

import segformer_eager.ops.*

% Shape is a vector of structs (one per shape element).
% Extract the values - some elements may be dlarray-wrapped scalars
% (from a layer's output boundary, which requires dlarray) rather than
% plain numerics; reshape() needs plain numbers either way.
shapeVals = {shape.value};
for iShapeVal = 1:numel(shapeVals)
    if isa(shapeVals{iShapeVal}, 'dlarray')
        shapeVals{iShapeVal} = extractdata(shapeVals{iShapeVal});
    end
end
shape = [shapeVals{:}];

    % Set the rank of Y to the number of dimensions in the original
    % shape vector
    Yrank = numel(shape);
    
    % Prepend the shape vector with ones so that it always contains at least
    % two elements
    shape = [ones(1, 2-numel(shape)) shape];

newShape = num2cell(shape);
if any(shape == -1)
    % Replace -1 with []
    i = shape == -1;
    newShape{i} = [];
end
revPythonShape = fliplr(newShape);
Xval = X.value;
Yval = reshape(Xval, revPythonShape{:});

Yval = dlarray(Yval, repmat('U', 1, max(2,Yrank)));

Y = struct('value',Yval,'rank', Yrank);

end
