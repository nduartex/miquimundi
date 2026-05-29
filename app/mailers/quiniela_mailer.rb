class QuinielaMailer < ApplicationMailer
  def confirmation(quiniela)
    @quiniela = quiniela
    @user = quiniela.user
    mail(to: @user.email, subject: "✅ Tu Quiniela Mundial fue registrada")
  end
end
