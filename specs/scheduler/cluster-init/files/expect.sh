#!/usr/bin/expect

log_file -a /shared/home/${CUSER}/expect.log

set timeout 5

spawn env LANG=C /home/${CUSER}/anaconda/bin/jupyter-notebook password 
expect { 
	"Enter password:" {
		send -- "EXPECTPASSWORD\n" 
	}
}
expect {
	"Verify password:\ " {
		send -- "EXPECTPASSWORD\n" 
	}
}
expect {
	"Wrote hashed password to /root/.jupyter/jupyter_notebook_config.json\n" {
		exit 0 
	}
}

