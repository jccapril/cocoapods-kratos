module Pod
  class Command
    class Kratos < Command
      private

      def spec_with_name(name)
        return if name.nil?

        set = Pod::Config.instance.sources_manager.search(Dependency.new(name))
        return nil if set.nil?

        set.specification.root
      end

      def spec_with_path(path)
        return if path.nil?
        path = Pathname.new(path)
        path = Pathname.new(Dir.pwd).join(path) unless path.absolute?
        return unless path.exist?

        @path = path.expand_path

        if @path.directory?
          help! @path + ': is a directory.'
          return
        end

        unless ['.podspec', '.json'].include? @path.extname
          help! @path + ': is not a podspec.'
          return
        end

        Specification.from_file(@path)
      end

    end
  end
end
