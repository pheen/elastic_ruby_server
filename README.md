# Todo
- [ ] usage lookup
- [ ] filter out configurable folders from project symbol search (e.g. vendor/)
- [ ] filter out let and let! definitions when outside of spec/ or test/
- [ ] profile `Persistence#index_all` and try to optimize
- [ ] maybe longer onChange debounce timer, then reindex first if go-to definition is triggered in the meantime

- [ ] check for branch switch, index new files and delete old ones

- [ ] attr_reader, etc.

- [] handle `class_methods` block
```
    class_methods do

      attr_writer :batch_size, :delay_to_batch_objects_together

      def key_from_context(context)
        context.try(:id) || context.to_s
      end

      ...
```