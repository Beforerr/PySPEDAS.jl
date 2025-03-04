# https://github.com/JuliaPy/PythonCall.jl/pull/509

"""
    pyconvert_dataarray(x; transpose=false)

Convert a `xarray.DataArray` to a `DimensionalData.DataArray`.

# Reference:
- https://github.com/rafaqz/DimensionalData.jl/blob/main/ext/DimensionalDataPythonCall.jl
"""
function pyconvert_dataarray(x; transpose=false)
    data_npy = transpose ? x.data.T : x.data
    data_type = dtype2type(string(data_npy.dtype.name))
    data_ndim = pyconvert(Int, data_npy.ndim)
    data = pyconvert(Array{data_type,data_ndim}, data_npy)

    dim_names = tuple(Symbol.(collect(x.dims))...)
    dim_names = transpose ? reverse(dim_names) : dim_names
    coord_names = Symbol.(collect(x.coords.keys()))
    lookups_values = map(dim_names) do dim
        if dim in coord_names
            coord = getproperty(x, dim).data
            coord_type = dtype2type(string(coord.dtype.name))
            coord_ndim = pyconvert(Int, coord.ndim)
            coord_type == DateTime ? pyconvert_time(coord) : pyconvert(Array{coord_type,coord_ndim}, coord)
        else
            NoLookup()
        end
    end

    lookups = NamedTuple{dim_names}(lookups_values)
    metadata = pyconvert(Dict, x.attrs)
    array_name = pyis(x.name, pybuiltins.None) ? nothing : string(x.name)

    return DimArray(data, lookups; name=array_name, metadata)
end

function dtype2type(dtype::String)
    if dtype == "float16"
        Float16
    elseif dtype == "float32"
        Float32
    elseif dtype == "float64"
        Float64
    elseif dtype == "int8"
        Int8
    elseif dtype == "int16"
        Int16
    elseif dtype == "int32"
        Int32
    elseif dtype == "int64"
        Int64
    elseif dtype == "uint8"
        UInt8
    elseif dtype == "uint16"
        UInt16
    elseif dtype == "uint32"
        UInt32
    elseif dtype == "uint64"
        UInt64
    elseif dtype == "bool"
        Bool
    elseif dtype == "datetime64[ns]"
        DateTime
    else
        error("Unsupported dtype: '$dtype'")
    end
end

"""
    pyconvert_time(time)

Convert `time` from Python to Julia.

Much faster than `pyconvert(Array, time)`
"""
function pyconvert_time(time)
    if length(time) == 0
        return DateTime[]
    end
    pydt_min = pyimport("numpy").timedelta64(1, "ns")
    dt_min = Nanosecond(1)
    pyt0 = time[0]
    t0 = pyconvert(DateTime, pyt0.astype("datetime64[s]").item()) # temporary solution, related to https://github.com/JuliaPy/PythonCall.jl/pull/509
    # t0 = pyconvert(DateTime, pyt0)
    dt_f = pyconvert(Array, (time - pyt0) / pydt_min)
    return t0 .+ dt_f .* dt_min
end