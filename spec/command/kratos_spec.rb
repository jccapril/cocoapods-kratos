require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Kratos do
    describe 'CLAide' do
      it 'registers it self' do
        Command.parse(%w{ kratos }).should.be.instance_of Command::Kratos
      end
    end
  end
end

