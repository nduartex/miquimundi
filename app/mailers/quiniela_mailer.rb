class QuinielaMailer < ApplicationMailer
  def confirmation(quiniela)
    @quiniela = quiniela
    @user = quiniela.user
    mail(to: @user.email, subject: "✅ Tu quiniela MiquiMundi quedó registrada")
  end
end
