module SimpleStructs

export @defstruct

"""A convenient macro copied from Mocha.jl that could be used to define structs
with default values and type checks. For example
```julia
@defstruct MyStruct Any (
  field1 :: Int = 0,
  (field2 :: AbstractString = "", !isempty(field2))
)
```
where each field could be either
```julia
field_name :: field_type = default_value
```
or put within a tuple, with the second element
specifying a validation check on the field value.
In the example above, the default value for
field2 does not satisfy the assertion, this
could be used to force user to provide a
valid value when no meaningful default value
is available.
The macro will define a constructor that could accept
the keyword arguments.
"""
macro defstruct(name, super_name, fields)
  @assert fields.head == :tuple
  fields     = fields.args
  @assert length(fields) > 0
  name       = esc(name)
  super_name = esc(super_name)

  field_defs     = Array(Expr, length(fields))        # :(field2 :: Int)
  field_names    = Array(Expr, length(fields))        # :field2
  field_defaults = Array(Expr, length(fields))        # :(field2 = 0)
  field_types    = Array(Expr, length(fields))        # Int
  field_asserts  = Array(Expr, length(fields))        # :(field2 >= 0)

  for i = 1:length(fields)
    field = fields[i]
    if field.head == :tuple
      field_asserts[i] = esc(field.args[2])
      field = field.args[1]
    end
    field_defs[i]     = esc(field.args[1])
    field_names[i]    = esc(field.args[1].args[1])
    field_types[i]    = esc(field.args[1].args[2])
    field_defaults[i] = Expr(:kw, field.args[1].args[1], esc(field.args[2]))
  end

  # body of layer type, defining fields
  type_body = Expr(:block, field_defs...)

  # constructor
  converts = map(zip(field_names, field_types)) do param
    f_name, f_type = param
    :($f_name = convert($f_type, $f_name))
  end
  asserts = map(filter(i -> isdefined(field_asserts,i), 1:length(fields))) do i
    :(@assert($(field_asserts[i])))
  end
  construct = Expr(:call, name, field_names...)
  ctor_body = Expr(:block, converts..., asserts..., construct)
  ctor_def = Expr(:call, name, Expr(:parameters, field_defaults...))
  ctor = Expr(:(=), ctor_def, ctor_body)

  quote
    type $(name) <: $super_name
      $type_body
    end

    $ctor
  end
end

end # module
