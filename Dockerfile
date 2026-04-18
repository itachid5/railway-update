FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor

# প্রয়োজনীয় প্যাকেজ ইন্সটল করা হচ্ছে
RUN apt-get update && apt-get install -y \
    openssh-server sudo curl wget git nano \
    && rm -rf /var/lib/apt/lists/*

# SSH ফোল্ডার তৈরি এবং ইউজার/পাসওয়ার্ড সেটআপ
RUN mkdir -p /var/run/sshd && \
    useradd -m -s /bin/bash -u 1000 devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "devuser:123456" | chpasswd && \
    echo "root:123456" | chpasswd && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# টার্মিনালে হোস্টনেম phoenix দেখানোর জন্য প্রম্পট (PS1) সেট করা হচ্ছে
RUN echo "export PS1='\[\e[32m\]\u@phoenix\[\e[m\]:\[\e[34m\]\w\[\e[m\]\$ '" >> /home/devuser/.bashrc && \
    echo "export PS1='\[\e[31m\]\u@phoenix\[\e[m\]:\[\e[34m\]\w\[\e[m\]# '" >> /root/.bashrc

# start.sh স্ক্রিপ্ট সরাসরি Dockerfile-এর ভেতরেই তৈরি করা হচ্ছে
RUN cat > /start.sh <<'SH'
#!/bin/bash
set -e

# SSH সার্ভার চালু করা হচ্ছে
/usr/sbin/sshd

# কন্টেইনারটি সচল রাখার জন্য
tail -f /dev/null
SH

# স্ক্রিপ্টটিকে এক্সিকিউটেবল করা হচ্ছে
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

WORKDIR /root

EXPOSE 22

CMD ["/start.sh"]
