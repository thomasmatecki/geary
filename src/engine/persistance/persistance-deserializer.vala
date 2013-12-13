/* Copyright 2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * A Deserializer turns specially-formatted bytes streams (generated by {@link Serializer}) into
 * Objects which implement {@link Serializable}.
 *
 * The {@link DataFlavor} given to the Deserializer must match the DataFlavor used to generate
 * the serialized stream.  There is no metadata in the stream to tell the Deserializer which to
 * use.
 *
 * See notes at Serializer for more information on how the serialized stream must be maintained by
 * the caller in order for Deserializer to operate properly.
 */

public class Geary.Persistance.Deserializer : BaseObject {
    private DataFlavor flavor;
    private Activator activator;
    
    public Deserializer(DataFlavor flavor, Activator activator) {
        this.flavor = flavor;
        this.activator = activator;
    }
    
    public Serializable from_buffer(Geary.Memory.Buffer buffer) throws Error {
        DataFlavorDeserializer deserializer = flavor.create_deserializer(buffer);
        
        return deserialize_properties(deserializer);
    }
    
    public Serializable deserialize_properties(DataFlavorDeserializer deserializer)
        throws Error {
        string classname = deserializer.get_classname();
        if (String.is_empty(classname))
            throw new PersistanceError.ACTIVATION("Unable to activate record: no classname");
        
        int version = deserializer.get_serialized_version();
        Serializable? sobj = activator.activate(classname, version);
        if (sobj == null)
            throw new PersistanceError.ACTIVATION("Unable to activate %s:%d", classname, version);
        
        foreach (ParamSpec param_spec in sobj.get_class().list_properties()) {
            // quietly pass over unserializable properties ... up to Activator to fill them with
            // values
            if (!is_serializable(param_spec, false))
                continue;
            
            if (!deserializer.has_value(param_spec.name)) {
                throw new PersistanceError.NOT_FOUND("Property %s not stored for class %s:%d",
                    param_spec.name, classname, version);
            }
            
            // Give the object the chance to manually deserialize the property
            if (sobj.deserialize_property(param_spec.name, deserializer))
                continue;
            
            Value value;
            switch (deserializer.get_value_type(param_spec.name)) {
                case SerializedType.BOOL:
                    value = Value(typeof(bool));
                    value.set_boolean(deserializer.get_bool(param_spec.name));
                break;
                
                case SerializedType.INT:
                    value = Value(typeof(int));
                    value.set_int(deserializer.get_int(param_spec.name));
                break;
                
                case SerializedType.INT64:
                    value = Value(typeof(int64));
                    value.set_int64(deserializer.get_int64(param_spec.name));
                break;
                
                case SerializedType.FLOAT:
                    value = Value(typeof(float));
                    value.set_float(deserializer.get_float(param_spec.name));
                break;
                
                case SerializedType.DOUBLE:
                    value = Value(typeof(double));
                    value.set_double(deserializer.get_double(param_spec.name));
                break;
                
                case SerializedType.UTF8:
                    value = Value(typeof(string));
                    value.set_string(deserializer.get_utf8(param_spec.name));
                break;
                
                case SerializedType.INT_ARRAY:
                case SerializedType.UTF8_ARRAY:
                    throw new PersistanceError.UNAVAILABLE("Property %s is an array, must be manually deserialized (%s:%d)",
                        param_spec.name, classname, version);
                
                default:
                    assert_not_reached();
            }
            
            sobj.set_property(param_spec.name, value);
        }
        
        return sobj;
    }
}
